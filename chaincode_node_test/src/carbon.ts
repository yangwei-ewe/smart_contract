'use strict';

import { Context, Contract } from 'fabric-contract-api';

interface Credit {
    owner: string;
    amount: number;
}

export default class CarbonContract extends Contract {

    async initLedger(ctx: Context): Promise<void> {
        console.info('Initializing Ledger');
        const credits: Credit[] = [
            { owner: 'org1', amount: 100 },
            { owner: 'org2', amount: 50 },
        ];

        for (let i = 0; i < credits.length; i++) {
            await ctx.stub.putState(`CREDIT${i}`, Buffer.from(JSON.stringify(credits[i])));
            console.info(`Credit ${i} initialized`);
        }
        console.log("init ok");
    }

    async issueCredit(ctx: Context, creditId: string, owner: string, amount: string): Promise<string> {
        const exists = await ctx.stub.getState(creditId);
        if (exists && exists.length > 0) {
            throw new Error(`Credit ${creditId} already exists`);
        }

        const credit: Credit = {
            owner,
            amount: parseInt(amount),
        };

        await ctx.stub.putState(creditId, Buffer.from(JSON.stringify(credit)));
        return JSON.stringify(credit);
    }

    async readCredit(ctx: Context, creditId: string): Promise<string> {
        const creditJSON = await ctx.stub.getState(creditId);
        if (!creditJSON || creditJSON.length === 0) {
            throw new Error(`Credit ${creditId} does not exist`);
        }
        return creditJSON.toString();
    }

    async transferCredit(ctx: Context, creditId: string, newOwner: string): Promise<string> {
        const creditJSON = await ctx.stub.getState(creditId);
        if (!creditJSON || creditJSON.length === 0) {
            throw new Error(`Credit ${creditId} does not exist`);
        }

        const credit: Credit = JSON.parse(creditJSON.toString());
        credit.owner = newOwner;

        await ctx.stub.putState(creditId, Buffer.from(JSON.stringify(credit)));
        return JSON.stringify(credit);
    }

    async getBalance(ctx: Context, owner: string): Promise<string> {
        const allResults: Credit[] = [];
        const iterator = await ctx.stub.getStateByRange('', '');

        while (true) {
            const res = await iterator.next();

            if (res.value && res.value.value.toString()) {
                const record: Credit = JSON.parse(res.value.value.toString());
                if (record.owner === owner) {
                    allResults.push(record);
                }
            }

            if (res.done) {
                await iterator.close();
                break;
            }
        }

        const total = allResults.reduce((sum, record) => sum + record.amount, 0);
        return JSON.stringify({ owner, balance: total });
    }
    async ledgerSanpshot(ctx: Context): Promise<void> {
        console.log("get msp id: ", ctx.stub.getMspID())
        console.log("history: ", ctx.stub.getHistoryForKey("0"))
        const credit = await ctx.stub.getStateByRange('', '')
        console.log(credit)
    }
}
