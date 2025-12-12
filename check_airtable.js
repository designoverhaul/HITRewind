// Quick script to check MTvVideos table in Airtable
const https = require('https');

const apiKey = 'pat9HXwt4uUaLl3SC.3a38959399a2a1d101c726e5e3ce154b37661244db837be7698a27cd18fd764b';
const baseId = 'appxCBIOkiJEZiph7';
const tableName = 'MTvVideos';

const url = `https://api.airtable.com/v0/${baseId}/${encodeURIComponent(tableName)}?maxRecords=5`;

const options = {
  headers: {
    'Authorization': `Bearer ${apiKey}`
  }
};

https.get(url, options, (res) => {
  let data = '';

  res.on('data', (chunk) => {
    data += chunk;
  });

  res.on('end', () => {
    if (res.statusCode === 200) {
      const response = JSON.parse(data);
      console.log('✅ MTvVideos table found!');
      console.log(`📊 Showing first ${response.records.length} records:\n`);

      response.records.forEach((record, index) => {
        console.log(`Record ${index + 1}:`);
        console.log('Fields:', Object.keys(record.fields));
        console.log('Sample data:', JSON.stringify(record.fields, null, 2));
        console.log('---');
      });
    } else {
      console.log(`❌ Error: ${res.statusCode}`);
      console.log(data);
    }
  });
}).on('error', (err) => {
  console.error('❌ Request failed:', err.message);
});
