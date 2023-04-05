

 

import fs from 'fs'
import readline from 'readline'

 /*

 fter the "BRDA" tag in an LCOV file, there are typically four numbers separated by commas. These numbers represent the branch coverage data for a particular branch in the code.

The four numbers have the following meanings:

    Line number: This is the line number in the source code where the branch occurs.

    Block number: This is the block number assigned to the branch by the compiler.

    Branches taken: This is the number of times the branch was taken during testing.

    Total branches: This is the total number of branches in the branch condition.

For example, the following line in an LCOV file indicates that on line 42 of the source file, block 0 had two branches, and one of those branches was taken once during testing:

BRDA:42,0,1,2
 */

const path = './lcov.info'
 

 async function process(){

const fileStream = fs.createReadStream(path);

const rl = readline.createInterface({
  input: fileStream,
  crlfDelay: Infinity
});
// Note: we use the crlfDelay option to recognize all instances of CR LF
// ('\r\n') in input.txt as a single line break.
 
for await (const line of rl) {

  if(line.startsWith('SF')){
    console.log(`---- ${line} ----`);

  }

  if(line.startsWith('FNDA:0')){

    const [FNDA, functionName] = line.split(':')

    console.log(`This function has zero test coverage: ${functionName}`);
  }

  
    if(line.startsWith('BRDA')){

     
        const [BRDA, branchValues] = line.split(':')

        const [lineNumber, blockNumber, branchesTaken, totalBranches] = branchValues.split(',')

        if(branchesTaken < totalBranches){

          console.log(`Branch not covered: line number:${lineNumber}, block number:${blockNumber}, [ ${branchesTaken} / ${totalBranches} ] `)

        }

    }
  // Each line in input.txt will be successively available here as `line`.
  
}
}

process();