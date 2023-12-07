export type PostCreatedEvent = {
    args: {
        postParams: {
            profileId: number;
            contentURI: string;
            actionModules: string[];
            actionModulesInitDatas: string[];
            referenceModule: string;
            referenceModuleInitData: string;
        };
        pubId: number;
        actionModulesInitReturnDatas: string[];
        referenceModuleInitReturnData: string;
        transactionExecutor: string;
        timestamp: number;
    };
    blockNumber: number;
    transactionHash: string;
};

export type PostCreatedEventFormatted = {
    args: {
        postParams: {
            profileId: string;
            contentURI: string;
            actionModules: string[];
            actionModulesInitDatas: string[];
            referenceModule: string;
            referenceModuleInitData: string;
        };
        pubId: string;
        actionModulesInitReturnDatas: string[];
        referenceModuleInitReturnData: string;
        transactionExecutor: string;
        timestamp: string;
    };
    blockNumber: string;
    transactionHash: string;
};

export type BetCreatedEvent = {
    args: {
        pubId: number;
        profileId: number;
        userId: number;
        jurorId: number;
        currency: string;
        amount: number;
        timestamp: number;
    }
    blockNumber: number;
    transactionHash: string;
}

export type BetCreatedEventFormatted = {
    args: {
        pubId: number;
        profileId: number;
        userId: number;
        jurorId: number;
        currency: string;
        amount: number;
        timestamp: number;
    }
    blockNumber: string;
    transactionHash: string;
}

export function convertPostEventToSerializable(
    event: PostCreatedEvent
): PostCreatedEventFormatted {
    return {
        ...event,
        args: {
            ...event.args,
            postParams: {
                ...event.args.postParams,
                profileId: event.args.postParams.profileId.toString(),
            },
            pubId: event.args.pubId.toString(),
            timestamp: event.args.timestamp.toString(),
        },
        blockNumber: event.blockNumber.toString(),
    };
}

export function convertBetCreatedEventToSerializable(
    event: BetCreatedEvent
): BetCreatedEventFormatted {
    return {
        ...event,
        blockNumber: event.blockNumber.toString(),
    };
}

export type LoginData = {
    handle: {
        fullHandle: string;
        localName: string;
    };
    id: string;
    ownedBy: {
        address: string;
    };
};