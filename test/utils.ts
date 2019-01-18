import {ContractTransaction, Signer} from "ethers";
import {ContractReceipt} from "ethers/contract";
import {BigNumber} from "ethers/utils";
import {JsonRpcProvider} from "ethers/providers";

export type Artifacts = { address: string; abi: string[] };

export async function transaction(transaction: Promise<ContractTransaction>): Promise<{ tx: ContractTransaction, receipt: ContractReceipt }> {
    const tx = await transaction;
    return {tx, receipt: await tx.wait()};
}

export async function increaseTime(deltaTime: number | BigNumber, provider: JsonRpcProvider) {
    await provider.send('evm_increaseTime', [deltaTime]);
    console.log("TIME INCREASED +" + deltaTime);
    const signer = provider.getSigner();
    await transaction(signer.sendTransaction({to: await signer.getAddress()}));
}
