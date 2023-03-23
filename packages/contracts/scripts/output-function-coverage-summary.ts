

 

import fs from 'fs'
import readline from 'readline'

 

const path = './lcov.info'
 

 async function process(){

const fileStream = fs.createReadStream(path);

const rl = readline.createInterface({
  input: fileStream,
  crlfDelay: Infinity
});
// Note: we use the crlfDelay option to recognize all instances of CR LF
// ('\r\n') in input.txt as a single line break.

console.log("These functions have zero test coverage:")
for await (const line of rl) {

  
    if(line.startsWith('FNDA:0')){

        console.log(`${line}`);
    }
  // Each line in input.txt will be successively available here as `line`.
  
}
}

process();