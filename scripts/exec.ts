import { NetworkProvider } from "@ton/blueprint";
import { Address, address, toNano } from "@ton/core";
import { CreateEscrowNativeCoin, Escrow } from "../wrappers/Escrow";

export async function run(provider: NetworkProvider) {
    const escrow = provider.open(Escrow.fromAddress(Address.parse("EQDboHxVVzOt2gROzYTBQvZ3DABvcnE5Qu2T-_AYxcgZzVmJ")));

    const escB = await escrow.getAllEscrowOrder();
    console.log("before", escB);

    const message: CreateEscrowNativeCoin = {
        $$type: 'CreateEscrowNativeCoin',
        _orderId: 6n,
        _taker: address("UQB4lw-RPXV2n9uNh32VvCG_Kzg9zED-MJwkFYYRtXv0KyoE") as Address,
        _value: toNano("3"),
        _maker_premium: false,
        _taker_premium: false,
    }

    await escrow.send(provider.sender(), {
        value: toNano(`${3.03 + 0.015}`)
    }, message)


    const status = await escrow.getEscrowOrder(6n);
    console.log({ status })

}