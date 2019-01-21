/// <reference types="chai" />

declare namespace Chai {
    // For BDD API
    interface Equal {
        BN(value: any, message?: string): Assertion;
        (value: any, message?: string): Assertion;
    }

    interface Assertion extends LanguageChains, NumericComparison, TypeComparison {
        equalIgnoreCase(value: any, message?: string): Assertion;
    }
}