// laptop_server.js
// Node.js + Express Server for WiDrop Link Sender
// Run with: node laptop_server.js
const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
const os = require('os');

const app = express();
const PORT = 8080;

app.use(cors());
app.use(express.json());

// Health check
app.get('/', (req, res) => {
  res.json({ status: 'online', port: PORT, message: 'WiDrop Laptop Server ready!' });
});

// Transfer endpoint
app.post('/api/transfer', (req, res) => {
  const { link, deviceName, folder } = req.body;
  const time = new Date().toLocaleString();

  console.log('-------------------------------------------');
  console.log(`📥 [NEW LINK] ${time}`);
  console.log(`📱 Device : ${deviceName}`);
  console.log(`🔗 Link   : ${link}`);
  console.log(`📁 Folder : ${folder}`);
  console.log('-------------------------------------------');

  // Ensure target folder exists in user home
  const targetDir = path.join(os.homedir(), folder || 'Downloads');
  try {
    fs.mkdirSync(targetDir, { recursive: true });
    const logPath = path.join(targetDir, 'received_links.txt');
    fs.appendFileSync(logPath, `[${time}] (${deviceName}) ${link}\\n`);
    console.log(`💾 Logged to ${logPath}`);
  } catch (err) {
    console.error('Folder note:', err.message);
  }

  res.json({
    status: 'success',
    message: `Link received on laptop from ${deviceName}!`,
    folder,
    receivedAt: time
  });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 WiDrop Laptop Server listening on http://0.0.0.0:${PORT}`);
  console.log(`📡 Connect your phone to the same Wi-Fi and send links to port ${PORT}`);
});
