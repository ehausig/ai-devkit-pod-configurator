const EventEmitter = require('events');
const fs = require('fs');
const readline = require('readline');
const Tail = require('tail').Tail;

class JournalReader extends EventEmitter {
  constructor(filePath) {
    super();
    this.filePath = filePath;
    this.tail = null;
    this.isRunning = false;
  }

  start() {
    if (this.isRunning) {
      console.log('Journal reader already running');
      return;
    }

    console.log(`Starting journal reader for: ${this.filePath}`);
    this.isRunning = true;

    // First, read existing content
    this.readExistingContent().then(() => {
      // Then start tailing for new events
      this.startTailing();
    }).catch(err => {
      console.error('Error reading existing journal:', err);
      this.emit('error', err);
    });
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

      rl.on('line', (line) => {
        this.processLine(line);
      });

      rl.on('close', () => {
        console.log('Finished reading existing journal content');
        resolve();
      });

      rl.on('error', (err) => {
        reject(err);
      });
    });
  }

  startTailing() {
    try {
      this.tail = new Tail(this.filePath, {
        fromBeginning: false,
        follow: true,
        logger: console
      });

      this.tail.on('line', (line) => {
        this.processLine(line);
      });

      this.tail.on('error', (error) => {
        console.error('Tail error:', error);
        this.emit('error', error);
      });

      console.log('Started tailing journal file');
    } catch (error) {
      console.error('Error starting tail:', error);
      this.emit('error', error);
    }
  }

  processLine(line) {
    if (!line || line.trim() === '') {
      return;
    }

    try {
      const event = JSON.parse(line);
      this.emit('event', event);
    } catch (error) {
      console.error('Error parsing journal line:', error);
      console.error('Line content:', line);
    }
  }

  stop() {
    if (this.tail) {
      this.tail.unwatch();
      this.tail = null;
    }
    this.isRunning = false;
    console.log('Journal reader stopped');
  }
}

module.exports = JournalReader;
