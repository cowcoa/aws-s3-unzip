'use strict';
console.log('Loading zxaws-ab unzip-patch function');

// Depend npm modules
const AdmZip = require('adm-zip');
const iconvlite = require('iconv-lite');
const moment = require('moment-timezone');
// Depend system modules
const AWS = require('aws-sdk');
const path = require('path');
// Global objects & variables
const s3 = new AWS.S3();
const ses = new AWS.SES();
const patchBucket = process.env['S3_BUCKET_DST'];
const sendEmail = process.env['SEND_EMAIL'];

function getObject(bucket, objectKey) {
    return new Promise((resolve, reject) => {
        s3.getObject({ Bucket: bucket, Key: objectKey }, (err, data) => {
            if (err) {
                reject(err);
            } else {
                resolve(data.Body);
            }
        });
    });
}

function putObject(bucket, objectKey, body) {
    return new Promise((resolve, reject) => {
        let s3_params = {
            Body: body,
            Bucket: bucket,
            Key: objectKey,
            ACL: "bucket-owner-full-control",
        };

        s3.putObject(s3_params, (err, fileBuffer) => {
            if (err) {
                reject(err);
            } else {
                resolve();
            }
        });
    });
}

exports.handler = function(event, context, callback) {
    console.log('Event: ' + JSON.stringify(event));
    console.log('Context: ' + JSON.stringify(context));

    let srcBucket = event.Records[0].s3.bucket.name;
    let srcObjectKey = event.Records[0].s3.object.key.replace(/\+/g, '%20');
    srcObjectKey = decodeURIComponent(srcObjectKey);

    console.log("bucket: " + srcBucket);
    console.log("object: " + srcObjectKey);

    let versionId = path.dirname(srcObjectKey);
    let resourceVersionId = path.basename(srcObjectKey, ".zip");

    console.log("versionId: " + versionId);
    console.log("resourceVersionId: " + resourceVersionId);
    
    if (versionId.length < 5) {
        callback("Invalid versionId");
        return;
    }
    
    const promise = Promise.resolve();
    promise.then(() => {
        // Get zipped patch file.
        return getObject(srcBucket, srcObjectKey);

    }).then((zipBody) => {
        // Unzip and sync patch files.
        let zip = new AdmZip(zipBody);
        let zipEntries = zip.getEntries();

        let promises = [];
        for (let i = 0; i < zipEntries.length; i++) {
            if (!zipEntries[i].isDirectory) {
                let patchKey = versionId + '/' + iconvlite.decode(zipEntries[i].rawEntryName, 'GBK');
                let decompressedData = zip.readFile(zipEntries[i]);
                promises.push(putObject(patchBucket, patchKey, decompressedData));
            }
        }

        // Waiting for all promises complete.
        Promise.all(promises).then(() => {
            if (sendEmail == true) {
                // Nofity Dev/Ops the result of patch deploment.
                // Generate deployment date, use +8 timezone for testing.
                let currentTime = moment().tz("Asia/Shanghai");
                let deployDate = currentTime.format();
                var params = {
                    Destination: {
                        ToAddresses: [
                            'zxaws@amazon.com'
                        ]
                    },
                    Message: {
                        Body: {
                            Html: {
                                Charset: "UTF-8",
                                Data: 'Patch ' + versionId + ':' + resourceVersionId + ' sync complete at ' + deployDate + '.'
                            },
                            Text: {
                                Charset: "UTF-8",
                                Data: 'Patch ' + versionId + ':' + resourceVersionId + ' sync complete at ' + deployDate + '.'
                            }
                        },
                        Subject: {
                            Charset: 'UTF-8',
                            Data: 'Patch ' + versionId + ':' + resourceVersionId + ' Deployment Notification'
                        }
                    },
                    Source: 'cowcoa@gmail.com'
                };
                
                console.log("Send a notification to mailbox: z***s@amazon.com");
                ses.sendEmail(params, (err, data) => {
                    if (err) {
                        console.log(err, err.stack);
                    } else {
                        console.log('Email sent successfully');
                    }
                });
            }
            
            callback(null, "OK");
            
        }).catch((err) => {
            callback(err, err.stack);
        });

    }).catch((err) => {
        callback(err, err.stack);
    });
};
