// Exits with CONTRACT_FIXTURE_EXIT when set, so the check can drive outcomes deterministically.
process.exit(Number(process.env.CONTRACT_FIXTURE_EXIT || 0));
