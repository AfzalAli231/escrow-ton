import { Blockchain, SandboxContract, TreasuryContract } from '@ton/sandbox';
import { Address, address, fromNano, toNano } from '@ton/core';
import { CreateEscrowNativeCoin, Escrow, CancelMakerNative, MarkPaid, ReleaseEscrowOnlyOwner, SetTime, TakerFee, RefundMakerNativeCoin, CancelTakerNative } from '../wrappers/Escrow';
import '@ton/test-utils';

describe('Escrow', () => {
    let blockchain: Blockchain;
    let deployer: SandboxContract<TreasuryContract>;
    let escrow: SandboxContract<Escrow>;

    beforeEach(async () => {
        blockchain = await Blockchain.create();

        escrow = blockchain.openContract(await Escrow.fromInit());

        deployer = await blockchain.treasury('deployer');

        const deployResult = await escrow.send(
            deployer.getSender(),
            {
                value: toNano('0.05'),
            },
            {
                $$type: 'Deploy',
                queryId: 0n,
            }
        );

        expect(deployResult.transactions).toHaveTransaction({
            from: deployer.address,
            to: escrow.address,
            deploy: true,
            success: true,
        });

        await escrow.send(
            deployer.getSender(),
            {
                value: toNano("10")
            },
            null as any
        )
    });

    it('should deploy', async () => {
        const balance = await escrow.getMakerFee();
        console.log(balance)
    });

    it('check fee', async () => {
        const user = await blockchain.treasury('user');
        const balanceBeforeUser = await escrow.getTakerFee()

        console.log((balanceBeforeUser))
        const message: TakerFee = {
            $$type: 'TakerFee',
            fee: BigInt(1800)
        }

        await escrow.send(user.getSender(), {
            value: toNano("0.5")
        }, message)

        const balanceAfterUser = await escrow.getOwner();
        console.log("owner", (balanceAfterUser))

    });

    it('create ton escrow', async () => {
        const user = await blockchain.treasury('user');
        const beforeBalance = await escrow.getBalance();
        const balanceBeforeUser = fromNano(beforeBalance);

        console.log((balanceBeforeUser))
        const message: CreateEscrowNativeCoin = {
            $$type: 'CreateEscrowNativeCoin',
            _orderId: 1n,
            _taker: address("UQDXMYwkYKpKGOFyXPHJ26S6zDX9x1tXrBTJVbP9fRnAgLKS") as Address,
            _value: toNano("2"),
            _maker_premium: false,
            _taker_premium: false,
        }

        await escrow.send(user.getSender(), {
            value: toNano("2.031")
        }, message)


        const eesc = await escrow.getEscrowOrder(1n);
        const bal = await escrow.getBalance();
        console.log("escrow order created", { eesc, bal: fromNano(bal) })
    });

    it('mark ton escrow as paid', async () => {
        const user = await blockchain.treasury('user');
        const beforeBalance = await user.getBalance();
        const balanceBeforeUser = fromNano(beforeBalance);

        console.log((balanceBeforeUser))
        const message: MarkPaid = {
            $$type: 'MarkPaid',
            orderId: 1n,
        }

        await escrow.send(user.getSender(), {
            value: toNano("2.02")
        }, message)


        // console.log({ abc: abc.transactions })
        const eesc = await escrow.getEscrowOrder(1n);
        const bal = await user.getBalance();
        console.log("escrow order maked as paid", { eesc, bal: fromNano(bal) })

    });

    it('release ton escrow', async () => {
        const user = await blockchain.treasury('user');
        const beforeBalance = await user.getBalance();
        const balanceBeforeUser = fromNano(beforeBalance);

        console.log((balanceBeforeUser))
        const rlse: ReleaseEscrowOnlyOwner = {
            $$type: 'ReleaseEscrowOnlyOwner',
            orderId: 1n,
        }

        await escrow.send(user.getSender(), {
            value: toNano("0.202")
        }, rlse)

        // console.log({ abc: abc.transactions })
        const eesc = await escrow.getEscrowOrder(1n);
        const bal = await user.getBalance();
        console.log("escrow order released", { eesc, bal: fromNano(bal) })

    });

    it('cancel as maker ton escrow', async () => {
        const user = await blockchain.treasury('user');
        const beforeBalance = await user.getBalance();
        const balanceBeforeUser = fromNano(beforeBalance);
        const statusBefore = await escrow.getEscrowOrder(1n);

        console.log({ status: statusBefore })

        console.log((balanceBeforeUser))
        const message: CancelMakerNative = {
            $$type: 'CancelMakerNative',
            orderId: 1n,
        }

        await escrow.send(user.getSender(), {
            value: toNano("2.02")
        }, message)

        // console.log({ abc: abc.transactions })
        const eesc = await escrow.getEscrowOrder(1n);
        const bal = await user.getBalance();
        console.log("escrow order refunded", { eesc, bal: fromNano(bal) })

    });

    it('cancel as taker ton escrow', async () => {
        const user = await blockchain.treasury('user');
        const beforeBalance = await user.getBalance();
        const balanceBeforeUser = fromNano(beforeBalance);
        const statusBefore = await escrow.getEscrowOrder(1n);

        console.log({ status: statusBefore })

        console.log((balanceBeforeUser))
        const message: CancelTakerNative = {
            $$type: 'CancelTakerNative',
            orderId: 1n,
        }

        await escrow.send(user.getSender(), {
            value: toNano("2.02")
        }, message)

        // console.log({ abc: abc.transactions })
        const eesc = await escrow.getEscrowOrder(1n);
        const bal = await user.getBalance();
        console.log("escrow order refunded", { eesc, bal: fromNano(bal) })

    });

    it('refund ton escrow', async () => {
        const user = await blockchain.treasury('user');
        const beforeBalance = await user.getBalance();
        const balanceBeforeUser = fromNano(beforeBalance);
        const statusBefore = await escrow.getEscrowOrder(1n);

        console.log({ status: statusBefore })

        console.log((balanceBeforeUser))
        const message: RefundMakerNativeCoin = {
            $$type: 'RefundMakerNativeCoin',
            _orderId: 1n,
        }

        await escrow.send(user.getSender(), {
            value: toNano("2.02")
        }, message)

        const eesc = await escrow.getEscrowOrder(1n);
        const bal = await user.getBalance();
        console.log("escrow order refunded", { eesc, bal: fromNano(bal) })

    });
});