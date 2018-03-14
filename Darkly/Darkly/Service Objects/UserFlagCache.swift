//
//  LDFlagCache.swift
//  Darkly
//
//  Created by Mark Pokorny on 7/24/17. +JMJ
//  Copyright © 2017 LaunchDarkly. All rights reserved.
//

import Foundation

//sourcery: AutoMockable
protocol UserFlagCaching {
    func cacheFlags(for user: LDUser)
    //sourcery: DefaultReturnValue = nil
    func retrieveFlags(for user: LDUser) -> CacheableUserFlags?
}

final class UserFlagCache: UserFlagCaching {
    struct Constants {
        public static let maxCachedValues = 5
    }

    struct Keys {
        fileprivate static let cachedFlags = "LDFlagCacheDictionary"
    }

    private let flagCollectionStore: FlagCollectionCaching

    init(flagCollectionStore: FlagCollectionCaching) {
        self.flagCollectionStore = flagCollectionStore
    }

    func cacheFlags(for user: LDUser) {
        var flags = cachedFlags
        flags[user.key] = CacheableUserFlags(user: user)
        cache(flags: flags)
    }
    
    func retrieveFlags(for user: LDUser) -> CacheableUserFlags? {
        return cachedFlags[user.key]
    }
    
    private var cachedFlags: [String: CacheableUserFlags] { return flagCollectionStore.retrieveFlags() }

    private func cache(flags: [String: CacheableUserFlags]) {
        flagCollectionStore.storeFlags(flags)
    }
}

// MARK: - Test Support
#if DEBUG
    extension UserFlagCache {
        static var flagCacheKey: String { return Keys.cachedFlags }
    }
#endif
