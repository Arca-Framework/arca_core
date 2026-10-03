-- Grade keys are strings ('0', '1', ...) to match qb-core's format, so qb job
-- files can be pasted in and qb scripts can index grades[tostring(level)].
--
-- bank = { minGrade = n } gives the job a shared account in arca_bank; grades >= minGrade can use it.
Arca.Shared.Jobs = {
    unemployed = {
        label = 'Civilian',
        defaultDuty = true,
        grades = { ['0'] = { name = 'Freelancer', payment = 10 } },
    },
    police = {
        label = 'Law Enforcement',
        type = 'leo',
        defaultDuty = true,
        bank = { minGrade = 3 },        -- Lieutenant and up can use the police account
        grades = {
            ['0'] = { name = 'Recruit', payment = 50 },
            ['1'] = { name = 'Officer', payment = 75 },
            ['2'] = { name = 'Sergeant', payment = 100 },
            ['3'] = { name = 'Lieutenant', payment = 125 },
            ['4'] = { name = 'Chief', payment = 150, isboss = true },
        },
    },
    ambulance = {
        label = 'EMS',
        type = 'ems',
        defaultDuty = true,
        bank = { minGrade = 2 },        -- Doctor and up can use the EMS account
        grades = {
            ['0'] = { name = 'Recruit', payment = 50 },
            ['1'] = { name = 'Paramedic', payment = 75 },
            ['2'] = { name = 'Doctor', payment = 100 },
            ['3'] = { name = 'Chief', payment = 150, isboss = true },
        },
    },
}
