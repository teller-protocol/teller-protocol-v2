 
 import { log } from "@graphprotocol/graph-ts";
 import { fac_DeployedLenderGroupContract as DeployedLenderGroupContract } from "./pb/contract/v1/fac_DeployedLenderGroupContract";
// import { Transaction } from "../generated/schema";
 import { Protobuf } from 'as-proto/assembly';

 
export function handleSubstreamGraphOutTrigger(bytes: Uint8Array): void {
  
  const deployedLenderGroupContractProto: DeployedLenderGroupContract = Protobuf.decode<DeployedLenderGroupContract>(bytes, DeployedLenderGroupContract.decode);
  
  log.info("Decoded a lender group contract from proto" , []);
  //const transactions = transactionsProto.transactions;
 


  /* let transactions = assembly.eth.transaction.v1.Transactions.decode(bytes.buffer).transactions;
  if (transactions.length == 0) {
      log.info("No transactions found", []);
      return;
  }

  for (let i = 0; i < transactions.length; i++) {
      let transaction = transactions[i];

      let entity = new Transaction(transaction.hash);
      entity.from = transaction.from;
      entity.to = transaction.to;
      entity.save();
  }  */
}
