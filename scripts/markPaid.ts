import { NetworkProvider } from "@ton/blueprint";
import { Address, toNano } from "@ton/core";
import { Escrow } from "../wrappers/Escrow";

export async function run(provider: NetworkProvider) {
    const escrow = provider.open(Escrow.fromAddress(Address.parse("EQDboHxVVzOt2gROzYTBQvZ3DABvcnE5Qu2T-_AYxcgZzVmJ")));

    const escB = await escrow.getAllEscrowOrder();
    console.log("before", escB);



    await escrow.send(
        provider.sender(),
        {
            value: toNano('0.008'),
        },
        {
            $$type: 'MarkPaid',
            orderId: 3n,
        }
    );

    const status = await escrow.getEscrowOrder(3n);
    console.log({ status })


}