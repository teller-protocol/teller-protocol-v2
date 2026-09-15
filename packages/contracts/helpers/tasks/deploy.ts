import { TASK_DEPLOY_RUN_DEPLOY } from 'hardhat-deploy'
import { subtask } from 'hardhat/config'

/**
 * Override `hardhat-deploy` deploy subtask to do some magic after it runs.
 */
subtask(TASK_DEPLOY_RUN_DEPLOY, async (args, hre, runSuper) => {
  if (!runSuper.isDefined) return

  await runSuper(args)

  // Export contract data
  await hre.run('export:deployments')

  // Only continue on a live network
  if (!hre.network.config.live) return

  // Verify contracts.
  //
  // This fires after *every* `hardhat deploy` on a live network, and a chain
  // deploy runs deploy three times — pass 1, pass 2, validate-deployments — so
  // a single deploy pays for three full verification sweeps. On a chain where
  // verification is failing that is most of the job's wall clock spent
  // producing identical errors, and it made a 5-minute deploy a 30-minute one.
  // SKIP_VERIFY opts out; verify-all can always be run on its own afterwards.
  if (process.env.SKIP_VERIFY === 'true') {
    console.log('Skipping verification (SKIP_VERIFY=true)')
    return
  }

  await hre.run('verify-all')
})
