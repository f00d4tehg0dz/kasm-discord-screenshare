const archiver = require('archiver');
const fs = require('fs');
const path = require('path');

const output = fs.createWriteStream('plex-discord-control@local.xpi');
const archive = archiver('zip', { zlib: { level: 9 } });

archive.on('error', (err) => {
  console.error('Error:', err);
  process.exit(1);
});

output.on('close', () => {
  const bytes = archive.pointer();
  console.log(`✓ Created plex-discord-control@local.xpi (${bytes} bytes)`);
  console.log('\nContents:');
  console.log('  manifest.json');
  console.log('  background.js');
  console.log('  content.js');
});

archive.pipe(output);

// Add files to archive
archive.file('manifest.json', { name: 'manifest.json' });
archive.file('background.js', { name: 'background.js' });
archive.file('content.js', { name: 'content.js' });

archive.finalize();