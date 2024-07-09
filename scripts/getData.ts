
import { NetworkProvider } from "@ton/blueprint";
import { Address } from "@ton/core";
import { Escrow } from "../wrappers/Escrow";

export async function run(provider: NetworkProvider) {
    const escrow = provider.open(Escrow.fromAddress(Address.parse("EQDboHxVVzOt2gROzYTBQvZ3DABvcnE5Qu2T-_AYxcgZzVmJ")));


    const status = await escrow.getEscrowOrder(1n);
    console.log({ status })




}