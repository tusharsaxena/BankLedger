-- Prose-gate waivers (localization-§5), per file AND per word, each with its reason.
-- Read by tests/_kit/test_prose.lua; nothing loads this file in the client.
return {
  waived = {
    -- `pending.cancelled` reads the kit timer handle's flag field (tests/_kit/mock_base.lua),
    -- which carries AceTimer's own spelling; renaming it is not this repo's English to correct.
    ["tests/test_sim_session.lua"] = { cancelled = true },
  },
}
