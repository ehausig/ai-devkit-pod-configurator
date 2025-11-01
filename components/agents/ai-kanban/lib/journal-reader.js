const EventEmitter = require('events');
const fs = require('fs');
const path = require('path');
const readline = require('readline');
const Tail = require('tail').Tail;

class JournalReader extends EventEmitter {
  constructor(filePath) {
    super();
    this.filePath = filePath;
    this.tail = null;
    this.isRunning = false;
    this.fileCheckInterval = null;
    this.fileExists = false;
  }

  start() {
    if (this.isRunning) {
      console.log('Journal reader already running');
      return;
    }

    console.log(`Starting journal reader for: ${this.filePath}`);
    this.isRunning = true;

    // Check if file exists
    if (!fs.existsSync(this.filePath)) {
      console.log('Journal file does not exist yet, will check periodically...');
      
      // Try to create the directory and file
      try {
        const dir = path.dirname(this.filePath);
        if (!fs.existsSync(dir)) {
          fs.mkdirSync(dir, { recursive: true });
          console.log(`Created directory: ${dir}`);
        }
        fs.writeFileSync(this.filePath, '');
        console.log(`Created empty journal file at: ${this.filePath}`);
      } catch (err) {
        console.log('Could not create journal file, will wait for it to be created by the system...');
      }
      
      this.emit('status', { 
        type: 'waiting', 
        message: 'Waiting for JOURNAL.md to be created...',
        details: 'The autonomous development system will create this file when you start a project.'
      });
      this.startFileWatcher();
      return;
    }

    // File exists, proceed with reading
    this.fileExists = true;
    this.emit('status', { type: 'connected', message: 'Connected to JOURNAL.md' });
    
    // First, read existing content
    this.readExistingContent().then(() => {
      // Then start tailing for new events
      this.startTailing();
    }).catch(err => {
      console.error('Error reading existing journal:', err);
      this.emit('error', err);
    });
  }

  startFileWatcher() {
    // Check every 5 seconds if the file has been created
    this.fileCheckInterval = setInterval(() => {
      if (fs.existsSync(this.filePath)) {
        console.log('Journal file detected! Starting to read...');
        clearInterval(this.fileCheckInterval);
        this.fileCheckInterval = null;
        this.fileExists = true;
        
        this.emit('status', { 
          type: 'connected', 
          message: 'JOURNAL.md found! Loading events...' 
        });
        
        // Start reading the file
        this.readExistingContent().then(() => {
          this.startTailing();
        }).catch(err => {
          console.error('Error reading journal:', err);
          this.emit('error', err);
        });
      }
    }, 5000); // Check every 5 seconds
  }

  async readExistingContent() {
    return new Promise((resolve, reject) => {
      if (!fs.existsSync(this.filePath)) {
        console.log('Journal file does not exist yet');
        resolve();
        return;
      }

      const fileStream = fs.createReadStream(this.filePath);
      const rl = readline.createInterface({
        input: fileStream,
        crlfDelay: Infinity
      });

      let lineCount = 0;
      rl.on('line', (line) => {
        lineCount++;
        this.processLine(line);
      });

      rl.on('close', () => {
        console.log(`Finished reading existing journal content (${lineCount} lines)`);
        resolve();
      });

      rl.on('error', (err) => {
        reject(err);
      });
    });
  }

  startTailing() {
    try {
      // Create file if it doesn't exist
      if (!fs.existsSync(this.filePath)) {
        const dir = path.dirname(this.filePath);
        if (!fs.existsSync(dir)) {
          fs.mkdirSync(dir, { recursive: true });
        }
        fs.writeFileSync(this.filePath, '');
        console.log('Created journal file for tailing');
      }

      // Use fromBeginning: false and useWatchFile for better compatibility
      this.tail = new Tail(this.filePath, {
        fromBeginning: false,
        follow: true,
        logger: console,
        useWatchFile: true,  // Better for files that might not exist initially
        flushAtEOF: true,    // Ensure we get all content
        fsWatchOptions: {
          interval: 100      // Poll every 100ms for faster updates
        }
      });

      this.tail.on('line', (line) => {
        this.processLine(line);
      });

      this.tail.on('error', (error) => {
        console.error('Tail error:', error);
        // Don't emit error for ENOENT as we handle this case
        if (error.code !== 'ENOENT') {
          this.emit('error', error);
        }
      });

      console.log('Started tailing journal file');
    } catch (error) {
      console.error('Error starting tail:', error);
      if (error.code === 'ENOENT') {
        // File was deleted after we started, go back to watching
        this.fileExists = false;
        this.emit('status', { 
          type: 'waiting', 
          message: 'JOURNAL.md was removed, waiting for it to be recreated...' 
        });
        this.startFileWatcher();
      } else {
        this.emit('error', error);
      }
    }
  }

  processLine(line) {
    if (!line || line.trim() === '') {
      return;
    }

    try {
      const event = JSON.parse(line);
      
      // Debug logging for development
      if (process.env.DEBUG_JOURNAL === 'true') {
        console.log('Parsed event:', {
          type: event.event_type,
          agent: event.agent,
          card: event.card_id
        });
      }
      
      this.emit('event', event);
    } catch (error) {
      console.error('Error parsing journal line:', error);
      console.error('Line content:', line.substring(0, 200) + (line.length > 200 ? '...' : ''));
    }
  }

  stop() {
    if (this.tail) {
      this.tail.unwatch();
      this.tail = null;
    }
    
    if (this.fileCheckInterval) {
      clearInterval(this.fileCheckInterval);
      this.fileCheckInterval = null;
    }
    
    this.isRunning = false;
    console.log('Journal reader stopped');
  }
}

module.exports = JournalReader;
