'use strict';

const { Contract } = require('fabric-contract-api');

class CarbonContract extends Contract {

    async initLedger(ctx) {
        console.info('Initializing Ledger');
        const credits = [
            {
                owner: 'org1',
                amount: 99999,
            },
            {
                owner: 'org2',
                amount: 100,
            }
        ];
        for (let i = 0; i < credits.length; i++) {
            await ctx.stub.putState(`CREDIT${i}`, Buffer.from(JSON.stringify(credits[i])));
            console.info(`Credit ${i} initialized`);
        }
        await ctx.stub.putState('LAST_PRICE', Buffer.from('-1'));
        await ctx.stub.putState('TRADE_HISTORY', Buffer.from(JSON.stringify([])));
        console.log("init ok")
    }

    async issueCredit(ctx, creditId, owner, amount) {
        const clientMSPID = ctx.clientIdentity.getMSPID();
        if (clientMSPID !== 'Org1MSP') {
            throw new Error('Only Org1 is authorized to issue credits');
        }

        const exists = await ctx.stub.getState(creditId);
        if (exists && exists.length > 0) {
            throw new Error(`Credit ${creditId} already exists`);
        }

        const credit = {
            owner,
            amount: parseInt(amount),
        };

        await ctx.stub.putState(creditId, Buffer.from(JSON.stringify(credit)));
        return JSON.stringify(credit);
    }

    async readCredit(ctx, creditId) {
        const creditJSON = await ctx.stub.getState(creditId);
        if (!creditJSON || creditJSON.length === 0) {
            throw new Error(`Credit ${creditId} does not exist`);
        }
        return creditJSON.toString();
    }

    async transferCredit(ctx, creditId, newOwner) {
        const creditJSON = await ctx.stub.getState(creditId);
        if (!creditJSON || creditJSON.length === 0) {
            throw new Error(`Credit ${creditId} does not exist`);
        }
        const credit = JSON.parse(creditJSON.toString());
        credit.owner = newOwner;

        await ctx.stub.putState(creditId, Buffer.from(JSON.stringify(credit)));
        return JSON.stringify(credit);
    }

    async getBalance(ctx, owner) {
        const allResults = [];
        const iterator = await ctx.stub.getStateByRange('', '');

        let result = await iterator.next();

        while (!result.done) {
            const kv = result.value;
            const key = kv.key;
            const value = kv.value.toString('utf8');
            const record = JSON.parse(value.toString('utf8'));
            if (record.owner === owner) {
                allResults.push(record);
            }
            result = await iterator.next();
        }

        await iterator.close();

        const total = allResults.reduce((sum, record) => sum + record.amount, 0);
        return JSON.stringify({ owner, balance: total, credits: allResults });
    }

    async snapshotLedger(ctx) {
        const iterator = await ctx.stub.getStateByRange('', '');
        const resultJson = {};

        let result = await iterator.next();

        while (!result.done) {
            const kv = result.value;
            const key = kv.key;
            const value = kv.value.toString('utf8');
            resultJson[key] = value;
            result = await iterator.next();
        }

        await iterator.close();
        console.log("Snapshot taken", resultJson);
        return JSON.stringify(resultJson);
    }

    async listOrder(ctx, owner, targetPrice, amount) {
        const order = {
            owner,
            targetPrice: parseFloat(targetPrice),
            amount: parseInt(amount),
            timestamp: new Date().toISOString(),
        };

        const tradeHistory = await this._getTradeHistory(ctx);
        const lastPrice = await this._getLastPrice(ctx);

        if (lastPrice >= order.targetPrice) {
            tradeHistory.push({ ...order, tradedPrice: lastPrice });
            await ctx.stub.putState('TRADE_HISTORY', Buffer.from(JSON.stringify(tradeHistory)));
            await ctx.stub.putState(`CREDIT_${Date.now()}`, Buffer.from(JSON.stringify({
                owner: order.owner,
                amount: order.amount
            })));
            return JSON.stringify({ status: 'matched', tradedPrice: lastPrice });
        } else {
            return JSON.stringify({ status: 'pending' });
        }
    }
    async burnCredit(ctx, owner, amount) {
        const balance = JSON.parse(await this.getBalance(ctx, owner));
        if (balance.balance < amount) {
            throw new Error(`Insufficient balance for owner ${owner}`);
        }
        const iterator = await ctx.stub.getStateByRange('', '');
        let result = await iterator.next();
        while (!result.done) {
            const kv = result.value;
            const key = kv.key;
            const value = kv.value.toString('utf8');
            const record = JSON.parse(value);
            if (record.owner === owner && record.amount >= amount) {
                record.amount -= amount;
                if (record.amount === 0) {
                    await ctx.stub.deleteState(key);
                } else {
                    await ctx.stub.putState(key, Buffer.from(JSON.stringify(record)));
                }
                return `Burned ${amount} credits from owner ${owner}`;
            }
            result = await iterator.next();
        }
        await iterator.close();
        throw new Error(`No sufficient credits found for owner ${owner} to burn ${amount}`);
    }

    async exportTradeHistory(ctx) {
        const tradeHistory = await this._getTradeHistory(ctx);
        return JSON.stringify(tradeHistory);
    }

    async updateLastPrice(ctx, price) {
        const numericPrice = parseFloat(price);
        await ctx.stub.putState('LAST_PRICE', Buffer.from(numericPrice.toString()));
        return `Last price updated to ${numericPrice}`;
    }

    async _getLastPrice(ctx) {
        const priceBuffer = await ctx.stub.getState('LAST_PRICE');
        return parseFloat(priceBuffer.toString());
    }

    async _getTradeHistory(ctx) {
        const buffer = await ctx.stub.getState('TRADE_HISTORY');
        if (!buffer || buffer.length === 0) return [];
        return JSON.parse(buffer.toString());
    }
}

module.exports = CarbonContract;
