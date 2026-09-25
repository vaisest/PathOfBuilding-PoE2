describe("TestTriggers", function()
	-- Select an active skill within a socket group as the main skill
	local function selectSkill(groupIndex, skillIndex)
		local group = build.skillsTab.socketGroupList[groupIndex]
		build.mainSocketGroup = groupIndex
		build.calcsTab.input.skill_number = groupIndex
		group.mainActiveSkill = skillIndex
		group.mainActiveSkillCalcs = skillIndex
		build.buildFlag = true
		build.modFlag = true
		runCallback("OnFrame")
		build.calcsTab:BuildOutput()
		runCallback("OnFrame")
	end

	-- The same product reached by a different order of operations
	local function assertNear(expected, actual)
		assert.is_true(math.abs(expected - actual) <= math.abs(expected) * 1e-9,
			("expected %s, got %s"):format(tostring(expected), tostring(actual)))
	end

	local function setConfig(var, value)
		build.configTab.input[var] = value
		build.configTab:BuildModList()
		build.buildFlag = true
		build.modFlag = true
		runCallback("OnFrame")
		build.calcsTab:BuildOutput()
		runCallback("OnFrame")
	end

	before_each(function()
		newBuild()
	end)

	teardown(function()
		-- newBuild() takes care of resetting everything in setup()
	end)

	describe("Meta gem Energy", function()
		it("Maximum Energy is 100 per second of base cast time of the socketed skill", function()
			build.skillsTab:PasteSocketGroup("Cast on Dodge 20/0  1\nSpark 20/0  1")
			runCallback("OnFrame")
			selectSkill(1, 2)
			-- Spark has a 0.7 second base cast time and no added total cast time
			assert.are.equals(70, build.calcsTab.mainOutput.MaxEnergy)
		end)

		it("Modifiers to total cast time count double towards maximum Energy", function()
			build.skillsTab:PasteSocketGroup("Cast on Dodge 20/0  1\nComet 20/0  1")
			runCallback("OnFrame")
			selectSkill(1, 2)
			-- Comet is 1.00s base cast time plus 1.00s of added total cast time
			assert.are.equals(100 * 1 + 200 * 1, build.calcsTab.mainOutput.MaxEnergy)
		end)

		it("Maximum Energy is the total of every socketed skill", function()
			build.skillsTab:PasteSocketGroup("Cast on Dodge 20/0  1\nComet 20/0  1\nSpark 20/0  1")
			runCallback("OnFrame")
			selectSkill(1, 2)
			assert.are.equals(300 + 70, build.calcsTab.mainOutput.MaxEnergy)
		end)

		it("All socketed skills trigger at the same rate", function()
			build.skillsTab:PasteSocketGroup("Cast on Dodge 20/0  1\nComet 20/0  1\nSpark 20/0  1")
			runCallback("OnFrame")
			selectSkill(1, 2)
			local cometRate = build.calcsTab.mainOutput.SkillTriggerRate
			selectSkill(1, 3)
			assert.are.equals(cometRate, build.calcsTab.mainOutput.SkillTriggerRate)
		end)
	end)

	describe("Cast on Dodge", function()
		it("gains 2 Energy per whole metre travelled while dodge rolling", function()
			build.skillsTab:PasteSocketGroup("Cast on Dodge 20/0  1\nSpark 20/0  1")
			runCallback("OnFrame")
			selectSkill(1, 2)
			setConfig("dodgeRollsPerSecond", 1)
			-- 4.5m base distance rounds down to 4m, 2 Energy each, +57% from gem level 20
			local energyPerRoll = 2 * 4 * 1.57
			assertNear(energyPerRoll, build.calcsTab.mainOutput.EnergyPerSecond)
			assertNear(energyPerRoll / 70, build.calcsTab.mainOutput.SkillTriggerRate)
		end)

		it("scales linearly with the number of dodge rolls per second", function()
			build.skillsTab:PasteSocketGroup("Cast on Dodge 20/0  1\nSpark 20/0  1")
			runCallback("OnFrame")
			selectSkill(1, 2)
			setConfig("dodgeRollsPerSecond", 1)
			local baseRate = build.calcsTab.mainOutput.SkillTriggerRate
			setConfig("dodgeRollsPerSecond", 2)
			assert.are.equals(baseRate * 2, build.calcsTab.mainOutput.SkillTriggerRate)
		end)

		it("drives the triggered skill's cast rate", function()
			build.skillsTab:PasteSocketGroup("Cast on Dodge 20/0  1\nSpark 20/0  1")
			runCallback("OnFrame")
			selectSkill(1, 2)
			setConfig("dodgeRollsPerSecond", 1)
			local output = build.calcsTab.mainOutput
			assert.is_true(output.SkillTriggerRate > 0)
			assert.are.equals(output.SkillTriggerRate, output.Speed)
		end)
	end)

	describe("Cast on Critical", function()
		local function setupCastOnCritical()
			build.skillsTab:PasteSocketGroup("Spark 20/0  1")
			runCallback("OnFrame")
			build.skillsTab:PasteSocketGroup("Cast on Critical 20/0  1\nComet 20/0  1")
			runCallback("OnFrame")
			selectSkill(2, 2)
		end

		it("finds the Critical Hit source and reports it", function()
			setupCastOnCritical()
			assert.are.equals("Cast on Critical's Trigger: Spark", build.calcsTab.mainEnv.player.mainSkill.infoMessage)
			assert.is_true(build.calcsTab.mainOutput.SkillTriggerRate > 0)
		end)

		it("gains Energy per Monster Power scaled by the hit's share of the Ailment Threshold", function()
			setupCastOnCritical()
			setConfig("monsterPower", 20)
			local output = build.calcsTab.mainOutput

			-- Recreate the source's contribution from its own cached output
			local env = build.calcsTab.mainEnv
			local sourceUUID = env.player.mainSkill.skillData.triggerSourceUUID
			local cached = GlobalCache.cachedData[env.mode][sourceUUID]
			local critDamage = 0
			for _, damageType in ipairs({"Physical", "Lightning", "Cold", "Fire", "Chaos"}) do
				critDamage = critDamage + (cached.Env.player.output[damageType.."CritAverage"] or 0)
			end
			local threshold = build.data.monsterAilmentThresholdTable[env.enemyLevel]
			local critsPerSecond = (cached.HitSpeed or cached.Speed) * cached.CritChance / 100
			local expected = 20 * critDamage / threshold * 1.57 * critsPerSecond

			assertNear(expected, output.EnergyPerSecond)
			assertNear(expected / 300, output.SkillTriggerRate)
		end)

		it("scales linearly with Monster Power", function()
			setupCastOnCritical()
			setConfig("monsterPower", 20)
			local baseRate = build.calcsTab.mainOutput.SkillTriggerRate
			setConfig("monsterPower", 10)
			assert.are.equals(baseRate / 2, build.calcsTab.mainOutput.SkillTriggerRate)
		end)

		it("falls back to self-cast when nothing can Critically Hit", function()
			build.skillsTab:PasteSocketGroup("Cast on Critical 20/0  1\nComet 20/0  1")
			runCallback("OnFrame")
			selectSkill(1, 2)
			local mainSkill = build.calcsTab.mainEnv.player.mainSkill
			assert.is_nil(mainSkill.skillData.triggered)
			assert.are.equals("No Cast on Critical Triggering Skill Found", mainSkill.infoMessage)
			assert.are.equals("DPS reported assuming Self-Cast", mainSkill.infoMessage2)
		end)
	end)
end)
