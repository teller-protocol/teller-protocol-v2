const fs = require("fs");
const path = require("path");
const shell = require("shelljs");

// Helper function to ensure directories exist
function ensureDirExists(dirPath) {
  if (!fs.existsSync(dirPath)) {
    fs.mkdirSync(dirPath, { recursive: true });
  }
}

// Helper function to delete JSON keys
function removeJsonKeys(filePath, keysToRemove) {
  const data = JSON.parse(fs.readFileSync(filePath, "utf-8"));
  keysToRemove.forEach(key => {
    delete data[key];
  });
  fs.writeFileSync(filePath, JSON.stringify(data, null, 2), "utf-8");
}

// Step 1: Clean and compile contracts
shell.exec("yarn clean");
shell.exec("yarn compile");

// Step 2: Copy contract artifacts
//const srcDir = "generated/artifacts/contracts";
const artifactsDir = "generated/artifacts/contracts"; 
const destDir = "build/contracts";
ensureDirExists(destDir);

shell.find(artifactsDir)
  .filter(filePath => {
    const isMockOrInterface = /\/(mock|interfaces)\//.test(filePath);
    const isDebugFile = filePath.endsWith("dbg.json");
    return !isMockOrInterface && !isDebugFile && filePath.endsWith(".json");
  })
  .forEach(filePath => {
    const relativePath = path.relative(artifactsDir, filePath);
    const destPath = path.join(destDir, relativePath);
    ensureDirExists(path.dirname(destPath));
    fs.copyFileSync(filePath, destPath);
  });

// Step 3: Copy Typechain typings
const typechainSrc = "generated/typechain";
const typechainDest = "build/typechain";
ensureDirExists(typechainDest); 
shell.ls("-A", typechainSrc).forEach(item => {
  const srcPath = path.join(typechainSrc, item);
  const destPath = path.join(typechainDest, item);
  if (fs.lstatSync(srcPath).isDirectory()) {
    ensureDirExists(destPath);
    shell.cp("-r", srcPath, destPath);
  } else {
    shell.cp(srcPath, destPath);
  }
});



//can inject just the ABIs ..
const nonDeployedContracts = {

 "1" : [
  "LenderCommitmentForwarder/extensions/LenderCommitmentGroup/LenderCommitmentGroupShares.sol/LenderCommitmentGroupShares.json",
  "LenderCommitmentForwarder/extensions/LenderCommitmentGroup/LenderCommitmentGroup_Smart.sol/LenderCommitmentGroup_Smart.json",
   "LenderCommitmentForwarder/extensions/LenderCommitmentGroup/LenderCommitmentGroup_Smart.sol/LenderCommitmentGroup_Pool_V2.json",
] ,
 

 "137" : [
  "LenderCommitmentForwarder/extensions/LenderCommitmentGroup/LenderCommitmentGroupShares.sol/LenderCommitmentGroupShares.json",
  "LenderCommitmentForwarder/extensions/LenderCommitmentGroup/LenderCommitmentGroup_Smart.sol/LenderCommitmentGroup_Smart.json",
  "LenderCommitmentForwarder/extensions/LenderCommitmentGroup/LenderCommitmentGroup_Smart.sol/LenderCommitmentGroup_Pool_V2.json",
] ,


 "42161" : [
  "LenderCommitmentForwarder/extensions/LenderCommitmentGroup/LenderCommitmentGroupShares.sol/LenderCommitmentGroupShares.json",
  "LenderCommitmentForwarder/extensions/LenderCommitmentGroup/LenderCommitmentGroup_Smart.sol/LenderCommitmentGroup_Smart.json",
  "LenderCommitmentForwarder/extensions/LenderCommitmentGroup/LenderCommitmentGroup_Smart.sol/LenderCommitmentGroup_Pool_V2.json",
] ,


  "8453" : [
     "LenderCommitmentForwarder/extensions/LenderCommitmentGroup/LenderCommitmentGroupShares.sol/LenderCommitmentGroupShares.json",
     "LenderCommitmentForwarder/extensions/LenderCommitmentGroup/LenderCommitmentGroup_Smart.sol/LenderCommitmentGroup_Smart.json",
     "LenderCommitmentForwarder/extensions/LenderCommitmentGroup/LenderCommitmentGroup_Smart.sol/LenderCommitmentGroup_Pool_V2.json",
    ]
};


// Step 4: Export contract deployments
const hardhatDir = "build/hardhat";
const contractsExportFile = path.join(hardhatDir, "contracts.json");
ensureDirExists(hardhatDir);

fs.writeFileSync(contractsExportFile, JSON.stringify({}, null, 2), "utf-8");
shell.exec(`yarn hardhat export --export-all ${contractsExportFile}`);

// Modify exported JSON
const exportData = JSON.parse(fs.readFileSync(contractsExportFile, "utf-8"));
delete exportData["31337"]; // Remove the "31337" key
 
 //  for each key (network.. ) 
Object.keys(exportData).forEach(key => {
  if (Array.isArray(exportData[key]) && exportData[key].length === 1) {
    // Replace the array with the single object inside it
    exportData[key] = exportData[key][0];
  }
});


Object.keys(exportData).forEach(key => {


    if ( Array.isArray( nonDeployedContracts[key] ) ){
    nonDeployedContracts[key].forEach(contractFilePath => {
      
      const abiPath = path.join(artifactsDir,  contractFilePath );

      
       const contractName = contractFilePath.split("/").pop().replace(".json", "");




      if (fs.existsSync(abiPath)) {
        const abiData = JSON.parse(fs.readFileSync(abiPath, "utf-8"));
        exportData[key]["contracts"][contractName] = {
          abi: abiData.abi
        };

          console.log("adding non-deployed contracts ",  contractName)

      } else {
        console.warn(`ABI for ${contractName} not found at ${abiPath}`);
      }
    });
  }


});


fs.writeFileSync(contractsExportFile, JSON.stringify(exportData, null, 2), "utf-8");

// ----- 

// Step 5: Compile math library helpers
shell.exec("yarn tsc -p teller-math-lib/tsconfig.json --outDir build/math");
