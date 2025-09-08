const fs = require('fs');
const mustache = require('mustache');
const path = require('path');

// Get network from command line args or default to mainnet
const network = process.argv[2] || 'mainnet';

console.log(`Generating subgraph.yaml for network: ${network}`);

// Read the template file
const templatePath = path.join(__dirname, '..', 'subgraph.template.yaml');
const template = fs.readFileSync(templatePath, 'utf8');

// Read the network config
const configPath = path.join(__dirname, '..', 'config', `${network}.json`);

if (!fs.existsSync(configPath)) {
  console.error(`Config file not found for network: ${network}`);
  process.exit(1);
}

const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));

// Prepare template variables
const templateVars = {
  network: config.network || network,
  startblock: config.contracts?.factory?.block || 0,
  lenderCommitmentGroupFactory: config.contracts?.factory?.address || '0x0000000000000000000000000000000000000000'
};

console.log('Template variables:', templateVars);

// Generate the subgraph.yaml
const output = mustache.render(template, templateVars);

// Write the output
const outputPath = path.join(__dirname, '..', 'subgraph.yaml');
fs.writeFileSync(outputPath, output);

console.log(`Generated subgraph.yaml successfully!`);