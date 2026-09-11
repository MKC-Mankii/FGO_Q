import { TEXT_CONFIG } from './text_config.js';

// 预设与全局配置常量
export const initialData = {
    groups: [
        {
            groupId: 0,
            name: "test", label: "大组 0: test", defaultScheme: 1,
            activityReward: 0,
            defaultFriend: "aobao",
            hint: TEXT_CONFIG.groups.defaultHints.test,
            schemes: [
                { friend: "aobao", dsl: "m22 | t1" },
                { friend: "aobao", dsl: "aB, B" },
                { friend: "aobao", dsl: "s20, 30, 40, 52, 70, 83 | a7, 8, 5;s10 | a6, 4, 5;s92, 50 | m22 | a7, 4, 5" }
            ]
        },
        {
            groupId: 1,
            name: "campaign", label: "大组 1: campaign", defaultScheme: 2,
            activityReward: 0,
            defaultFriend: "",
            hint: TEXT_CONFIG.groups.defaultHints.campaign,
            schemes: [
                { friend: "mary", dsl: "s50 | a7, 4, 5;s40 | m32 | s32, 50, 60 | t1 | aB, Q, A;s70, 92, 40 | a7, B, B" },
                { friend: "rba", dsl: "s72, 80, 91, 10, 20, 30, 40, 50, 60 | m22 | a6, 7, 5" },
                { friend: "aobao", dsl: "s20, 30, 40, 52, 70, 83 | a7, 8, 5;s10 | a6, 4, 5;s92, 50 | m22 | a7, 4, 5" }
            ]
        },
        {
            groupId: 2,
            name: "caber", label: "大组 2: caber", defaultScheme: 2,
            activityReward: 0,
            defaultFriend: "cdai",
            hint: TEXT_CONFIG.groups.defaultHints.caber,
            schemes: [
                { friend: "cdai", dsl: "s23, 33, 53, 63, 70, 90, 83 | m30 | a8, 4, 5;s10 | a8, 4, 5;s40 | m13 | a8, 4, 5" },
                { friend: "cdai", dsl: "s10, 20, 53, 63, 70, 90, 83 | m30 | a8, 4, 5;s40 | a8, 4, 5;s33 | m10 | a8, 4, 5" },
                { friend: "cdai", dsl: "s10, 20, 53, 63, 80, 90 | a8, 4, 5;s40 | a8, 4, 5;s33 | m10, 30 | a8, 4, 5" }
            ]
        },
        {
            groupId: 3,
            name: "grand", label: "大组 3: grand", defaultScheme: 3,
            activityReward: 0,
            defaultFriend: "",
            hint: TEXT_CONFIG.groups.defaultHints.grand,
            schemes: [
                { friend: "sparrow", dsl: "s40, 53, 60 | m30024, 10 | s40, 10, 20, 30, 70, 80, 90 | a8, 6, B" },
                { friend: "Cba", dsl: "s10, 30 | m30014, 10 | s10, 20, 40, 50, 60, 70, 83, 90 | a7, 8, A" },
                { friend: "keli", dsl: "s90, 80, 70, | m30034, 10 | s80, 70, 60, 50, 40, 31, 21, 10 | a6, 7, 5" },
                { friend: "Bdai", dsl: "s10, 40, 52, 60, 70, 83, 90 | m22 | a7, 8, A" },
                { friend: "princess", dsl: "s12, 20, 32, 40, 50, 60, 70, 80 | m30014, 10 | s30 | a8, 7, B" },
                { friend: "aobao", dsl: "s70, 82, 92, 60, 50, 40, 20 | m22 | a7, B, B" }
            ]
        },
        {
            groupId: 4,
            name: "ordeal", label: "大组 4: ordeal", defaultScheme: 1,
            activityReward: 0,
            defaultFriend: "shahushan",
            hint: TEXT_CONFIG.groups.defaultHints.ordeal,
            schemes: [
                { friend: "shahushan", dsl: "s10, 20, 30, 51, 61, 71, 80, 91 | m31 | aB, 6, B;s41, 10, 20, 30 | a6, B, B" },
                { friend: "shahushan", dsl: "s92, 40, 50, 60, 30 | a7, B, B;s72 | m32 | s50 | aB, 7, B;s82, 60 | a7, B, B" },
                { friend: "shahushan", dsl: "s10, 20, 30, 41, 51, 61, 71, 91 | m31 | aB, 6, B;s10, 20, 30 | a6, B, B" },
                { friend: "shahushan", dsl: "s10, 20, 40, 50, 62, 70, 92 | m22 | a7, 4, 5" }
            ]
        }
    ]
};

export const SUPPORTED_FRIENDS = TEXT_CONFIG.supportedFriends;
export const CARD_INFO = TEXT_CONFIG.cards.cardInfoLabels;
export const DEFAULT_ROUND_ATTACK = ['7', '4', '5'];

