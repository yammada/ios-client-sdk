//
//  FlagStoreSpec.swift
//  LaunchDarklyTests
//
//  Copyright © 2017 Catamorphic Co. All rights reserved.
//

import Foundation
import Quick
import Nimble
@testable import LaunchDarkly

final class FlagStoreSpec: QuickSpec {

    struct FlagKeys {
        static let newInt = "new-int-flag"
    }

    struct DefaultValues {
        static let bool = false
        static let int = 3
        static let double = 2.71828
        static let string = "defaultValue string"
        static let array = [0]
        static let dictionary: [String: Any] = [DarklyServiceMock.FlagKeys.string: DarklyServiceMock.FlagValues.string]
    }

    struct TestContext {
        let flagStore: FlagStore!
        let featureFlags: [LDFlagKey: FeatureFlag]!

        init() {
            featureFlags = DarklyServiceMock.Constants.stubFeatureFlags()
            flagStore = FlagStore(featureFlags: featureFlags)
        }
    }

    override func spec() {
        initSpec()
        replaceStoreSpec()
        updateStoreSpec()
        deleteFlagSpec()
        featureFlagSpec()
    }

    func initSpec() {
        var subject: FlagStore!
        var featureFlags: [LDFlagKey: FeatureFlag]!
        describe("init") {
            context("without an initial flag store") {
                it("has no feature flags") {
                    subject = FlagStore()
                    expect(subject.featureFlags.isEmpty) == true
                }
            }
            context("with an initial flag store") {
                it("has matching feature flags") {
                    featureFlags = DarklyServiceMock.Constants.stubFeatureFlags()
                    subject = FlagStore(featureFlags: featureFlags)
                    expect(subject.featureFlags) == featureFlags
                }
            }
            context("with an initial flag store without elements") {
                it("has matching feature flags") {
                    featureFlags = DarklyServiceMock.Constants.stubFeatureFlags(includeVariations: false, includeVersions: false, includeFlagVersions: false)
                    subject = FlagStore(featureFlags: featureFlags)
                    expect(subject.featureFlags) == featureFlags
                }
            }
            context("with an initial flag dictionary") {
                it("has the feature flags") {
                    featureFlags = DarklyServiceMock.Constants.stubFeatureFlags()
                    subject = FlagStore(featureFlagDictionary: featureFlags.dictionaryValue)
                    expect(subject.featureFlags) == featureFlags
                }
            }
        }
    }

    func replaceStoreSpec() {
        let featureFlags: [LDFlagKey: FeatureFlag] = DarklyServiceMock.Constants.stubFeatureFlags(includeNullValue: false)
        var flagStore: FlagStore!
        describe("replaceStore") {
            context("with new flag values") {
                it("causes FlagStore to replace the flag values") {
                    flagStore = FlagStore()
                    waitUntil(timeout: .seconds(1)) { done in
                        flagStore.replaceStore(newFlags: featureFlags, completion: done)
                    }
                    expect(flagStore.featureFlags) == featureFlags
                }
            }
            context("with new flag value dictionary") {
                it("causes FlagStore to replace the flag values") {
                    flagStore = FlagStore()
                    waitUntil(timeout: .seconds(1)) { done in
                        flagStore.replaceStore(newFlags: featureFlags.dictionaryValue, completion: done)
                    }
                    expect(flagStore.featureFlags) == featureFlags
                }
            }
            context("with invalid dictionary") {
                it("causes FlagStore to empty the flag values") {
                    flagStore = FlagStore(featureFlags: featureFlags)
                    waitUntil(timeout: .seconds(1)) { done in
                        flagStore.replaceStore(newFlags: ["fakeKey": "Not a flag dict"], completion: done)
                    }
                    expect(flagStore.featureFlags.isEmpty).to(beTrue())
                }
            }
        }
    }

    func updateStoreSpec() {
        var testContext: TestContext!
        var updateDictionary: [String: Any]!
        describe("updateStore") {
            beforeEach {
                testContext = TestContext()
            }
            context("when feature flag does not already exist") {
                beforeEach {
                    updateDictionary = FlagMaintainingMock.stubPatchDictionary(key: FlagKeys.newInt,
                                                                               value: DarklyServiceMock.FlagValues.alternate(DarklyServiceMock.FlagValues.int),
                                                                               variation: DarklyServiceMock.Constants.variation,
                                                                               version: DarklyServiceMock.Constants.version)

                    waitUntil { done in
                        testContext.flagStore.updateStore(updateDictionary: updateDictionary, completion: done)
                    }
                }
                it("adds the new flag to the store") {
                    let featureFlag = testContext.flagStore.featureFlags[FlagKeys.newInt]
                    expect(AnyComparer.isEqual(featureFlag?.value, to: updateDictionary?.value)).to(beTrue())
                    expect(featureFlag?.variation) == updateDictionary?.variation
                    expect(featureFlag?.version) == updateDictionary?.version
                }
            }
            context("when the feature flag exists") {
                context("and the update version > existing version") {
                    beforeEach {
                        updateDictionary = FlagMaintainingMock.stubPatchDictionary(key: DarklyServiceMock.FlagKeys.int,
                                                                                   value: DarklyServiceMock.FlagValues.alternate(DarklyServiceMock.FlagValues.int),
                                                                                   variation: DarklyServiceMock.Constants.variation + 1,
                                                                                   version: DarklyServiceMock.Constants.version + 1)

                        waitUntil { done in
                            testContext.flagStore.updateStore(updateDictionary: updateDictionary, completion: done)
                        }
                    }
                    it("updates the feature flag to the update value") {
                        let featureFlag = testContext.flagStore.featureFlags[DarklyServiceMock.FlagKeys.int]
                        expect(AnyComparer.isEqual(featureFlag?.value, to: updateDictionary?.value)).to(beTrue())
                        expect(featureFlag?.variation) == updateDictionary?.variation
                        expect(featureFlag?.version) == updateDictionary?.version
                    }
                }
                context("and the new value is null") {
                    beforeEach {
                        updateDictionary = FlagMaintainingMock.stubPatchDictionary(key: DarklyServiceMock.FlagKeys.int,
                                                                                   value: NSNull(),
                                                                                   variation: DarklyServiceMock.Constants.variation + 1,
                                                                                   version: DarklyServiceMock.Constants.version + 1)

                        waitUntil { done in
                            testContext.flagStore.updateStore(updateDictionary: updateDictionary, completion: done)
                        }
                    }
                    it("updates the feature flag to the update value") {
                        let featureFlag = testContext.flagStore.featureFlags[DarklyServiceMock.FlagKeys.int]
                        expect(featureFlag?.value).to(beNil())
                        expect(featureFlag?.variation) == updateDictionary.variation
                        expect(featureFlag?.version) == updateDictionary.version
                    }
                }
                context("and the update version == existing version") {
                    beforeEach {
                        updateDictionary = FlagMaintainingMock.stubPatchDictionary(key: DarklyServiceMock.FlagKeys.int,
                                                                                   value: DarklyServiceMock.FlagValues.alternate(DarklyServiceMock.FlagValues.int),
                                                                                   variation: DarklyServiceMock.Constants.variation,
                                                                                   version: DarklyServiceMock.Constants.version)

                        waitUntil { done in
                            testContext.flagStore.updateStore(updateDictionary: updateDictionary, completion: done)
                        }
                    }
                    it("does not change the feature flag value") {
                        expect(testContext.flagStore.featureFlags) == testContext.featureFlags
                    }
                }
                context("and the update version < existing version") {
                    beforeEach {
                        updateDictionary = FlagMaintainingMock.stubPatchDictionary(key: DarklyServiceMock.FlagKeys.int,
                                                                                   value: DarklyServiceMock.FlagValues.alternate(DarklyServiceMock.FlagValues.int),
                                                                                   variation: DarklyServiceMock.Constants.variation - 1,
                                                                                   version: DarklyServiceMock.Constants.version - 1)

                        waitUntil { done in
                            testContext.flagStore.updateStore(updateDictionary: updateDictionary, completion: done)
                        }
                    }
                    it("does not change the feature flag value") {
                        expect(testContext.flagStore.featureFlags) == testContext.featureFlags
                    }
                }
            }
            context("when the update dictionary is missing the flagKey") {
                beforeEach {
                    updateDictionary = FlagMaintainingMock.stubPatchDictionary(key: nil,
                                                                               value: DarklyServiceMock.FlagValues.alternate(DarklyServiceMock.FlagValues.int),
                                                                               variation: DarklyServiceMock.Constants.variation + 1,
                                                                               version: DarklyServiceMock.Constants.version + 1)

                    waitUntil { done in
                        testContext.flagStore.updateStore(updateDictionary: updateDictionary, completion: done)
                    }
                }
                it("makes no changes") {
                    expect(testContext.flagStore.featureFlags) == testContext.featureFlags
                }
            }
            context("when the update dictionary is missing the value") {
                beforeEach {
                    updateDictionary = FlagMaintainingMock.stubPatchDictionary(key: DarklyServiceMock.FlagKeys.int,
                                                                               value: nil,
                                                                               variation: DarklyServiceMock.Constants.variation + 1,
                                                                               version: DarklyServiceMock.Constants.version + 1)

                    waitUntil { done in
                        testContext.flagStore.updateStore(updateDictionary: updateDictionary, completion: done)
                    }
                }
                it("updates the feature flag to the update value") {
                    let featureFlag = testContext.flagStore.featureFlags[DarklyServiceMock.FlagKeys.int]
                    expect(AnyComparer.isEqual(featureFlag?.value, to: updateDictionary.value)).to(beTrue())
                    expect(featureFlag?.variation) == updateDictionary.variation
                    expect(featureFlag?.version) == updateDictionary.version
                }
            }
            context("when the update dictionary is missing the variation") {
                beforeEach {
                    updateDictionary = FlagMaintainingMock.stubPatchDictionary(key: DarklyServiceMock.FlagKeys.int,
                                                                               value: DarklyServiceMock.FlagValues.alternate(DarklyServiceMock.FlagValues.int),
                                                                               variation: nil,
                                                                               version: DarklyServiceMock.Constants.version + 1)

                    waitUntil { done in
                        testContext.flagStore.updateStore(updateDictionary: updateDictionary, completion: done)
                    }
                }
                it("updates the feature flag to the update value") {
                    let featureFlag = testContext.flagStore.featureFlags[DarklyServiceMock.FlagKeys.int]
                    expect(AnyComparer.isEqual(featureFlag?.value, to: updateDictionary.value)).to(beTrue())
                    expect(featureFlag?.variation).to(beNil())
                    expect(featureFlag?.version) == updateDictionary.version
                }
            }
            context("when the update dictionary is missing the version") {
                beforeEach {
                    updateDictionary = FlagMaintainingMock.stubPatchDictionary(key: DarklyServiceMock.FlagKeys.int,
                                                                               value: DarklyServiceMock.FlagValues.alternate(DarklyServiceMock.FlagValues.int),
                                                                               variation: DarklyServiceMock.Constants.variation + 1,
                                                                               version: nil)

                    waitUntil { done in
                        testContext.flagStore.updateStore(updateDictionary: updateDictionary, completion: done)
                    }
                }
                it("updates the feature flag to the update value") {
                    let featureFlag = testContext.flagStore.featureFlags[DarklyServiceMock.FlagKeys.int]
                    expect(AnyComparer.isEqual(featureFlag?.value, to: updateDictionary.value)).to(beTrue())
                    expect(featureFlag?.variation) == updateDictionary.variation
                    expect(featureFlag?.version).to(beNil())
                }
            }
            context("when the update dictionary has more keys than needed") {
                beforeEach {
                    updateDictionary = FlagMaintainingMock.stubPatchDictionary(key: DarklyServiceMock.FlagKeys.int,
                                                                               value: DarklyServiceMock.FlagValues.alternate(DarklyServiceMock.FlagValues.int),
                                                                               variation: DarklyServiceMock.Constants.variation + 1,
                                                                               version: DarklyServiceMock.Constants.version + 1,
                                                                               includeExtraKey: true)

                    waitUntil { done in
                        testContext.flagStore.updateStore(updateDictionary: updateDictionary, completion: done)
                    }
                }
                it("updates the feature flag to the update value") {
                    let featureFlag = testContext.flagStore.featureFlags[DarklyServiceMock.FlagKeys.int]
                    expect(AnyComparer.isEqual(featureFlag?.value, to: updateDictionary.value)).to(beTrue())
                    expect(featureFlag?.variation) == updateDictionary.variation
                    expect(featureFlag?.version) == updateDictionary.version
                }
            }
        }
    }

    func deleteFlagSpec() {
        var testContext: TestContext!
        var deleteDictionary: [String: Any]!
        describe("deleteFlag") {
            beforeEach {
                testContext = TestContext()
            }
            context("when the flag exists") {
                context("and the new version > existing version") {
                    beforeEach {
                        deleteDictionary = FlagMaintainingMock.stubDeleteDictionary(key: DarklyServiceMock.FlagKeys.int, version: DarklyServiceMock.Constants.version + 1)

                        waitUntil { done in
                            testContext.flagStore.deleteFlag(deleteDictionary: deleteDictionary, completion: done)
                        }
                    }
                    it("removes the feature flag from the store") {
                        expect(testContext.flagStore.featureFlags[DarklyServiceMock.FlagKeys.int]).to(beNil())
                    }
                }
                context("and the new version == existing version") {
                    beforeEach {
                        deleteDictionary = FlagMaintainingMock.stubDeleteDictionary(key: DarklyServiceMock.FlagKeys.int, version: DarklyServiceMock.Constants.version)

                        waitUntil { done in
                            testContext.flagStore.deleteFlag(deleteDictionary: deleteDictionary, completion: done)
                        }
                    }
                    it("makes no changes to the flag store") {
                        expect(testContext.flagStore.featureFlags) == testContext.featureFlags
                    }
                }
                context("and the new version < existing version") {
                    beforeEach {
                        deleteDictionary = FlagMaintainingMock.stubDeleteDictionary(key: DarklyServiceMock.FlagKeys.int, version: DarklyServiceMock.Constants.version - 1)

                        waitUntil { done in
                            testContext.flagStore.deleteFlag(deleteDictionary: deleteDictionary, completion: done)
                        }
                    }
                    it("makes no changes to the flag store") {
                        expect(testContext.flagStore.featureFlags) == testContext.featureFlags
                    }
                }
            }
            context("when the flag doesn't exist") {
                beforeEach {
                    deleteDictionary = FlagMaintainingMock.stubDeleteDictionary(key: FlagKeys.newInt, version: DarklyServiceMock.Constants.version + 1)

                    waitUntil { done in
                        testContext.flagStore.deleteFlag(deleteDictionary: deleteDictionary, completion: done)
                    }
                }
                it("makes no changes to the flag store") {
                    expect(testContext.flagStore.featureFlags) == testContext.featureFlags
                }
            }
            context("when delete dictionary is missing the key") {
                beforeEach {
                    deleteDictionary = FlagMaintainingMock.stubDeleteDictionary(key: nil, version: DarklyServiceMock.Constants.version + 1)

                    waitUntil { done in
                        testContext.flagStore.deleteFlag(deleteDictionary: deleteDictionary, completion: done)
                    }
                }
                it("makes no changes to the flag store") {
                    expect(testContext.flagStore.featureFlags) == testContext.featureFlags
                }
            }
            context("when delete dictionary is missing the version") {
                beforeEach {
                    deleteDictionary = FlagMaintainingMock.stubDeleteDictionary(key: DarklyServiceMock.FlagKeys.int, version: nil)

                    waitUntil { done in
                        testContext.flagStore.deleteFlag(deleteDictionary: deleteDictionary, completion: done)
                    }
                }
                it("makes no changes to the flag store") {
                    expect(testContext.flagStore.featureFlags) == testContext.featureFlags
                }
            }
        }
    }

    func featureFlagSpec() {
        var flagStore: FlagStore!
        describe("featureFlag") {
            beforeEach {
                flagStore = FlagStore(featureFlags: DarklyServiceMock.Constants.stubFeatureFlags())
            }
            context("when flag key exists") {
                it("returns the feature flag") {
                    flagStore.featureFlags.forEach { flagKey, featureFlag in
                        expect(flagStore.featureFlag(for: flagKey)?.allPropertiesMatch(featureFlag)).to(beTrue())
                    }
                }
            }
            context("when flag key doesn't exist") {
                it("returns nil") {
                    let featureFlag = flagStore.featureFlag(for: DarklyServiceMock.FlagKeys.unknown)
                    expect(featureFlag).to(beNil())
                }
            }
        }
    }
}
