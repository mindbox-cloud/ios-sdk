//
//  LocalStoriesConfigOverride.swift
//  Mindbox
//
//  LOCAL VERIFICATION HARNESS — LIVES ONLY WHILE MOBILE-332 IS IN PROGRESS.
//
//  Replaces the downloaded mobile config with the stories fixture so the embedded block and the feed
//  can be driven end to end without a backend. Committed on purpose so the branch needs no
//  uncommitted state; the warning below shouts from every build until it is gone. Delete this file
//  and its one call site in InAppConfigurationManager.downloadConfig() before the PR — the call
//  site stops compiling the moment the file is removed, so it cannot be forgotten halfway.
//
//  A ready-to-serve copy of the assembled JSON lives in docs/MOBILE-332/qa/ for substituting the
//  real config response through a proxy — regenerate it after editing the tables here (the dump
//  command is in that folder's README).
//

// swiftlint:disable all

import Foundation

#warning("MOBILE-332: local stories config harness is active — delete this file and its call in downloadConfig() before the PR")

enum LocalStoriesConfigOverride {

    /// Off inside a test run: the unit suite drives the real download path and must not have it
    /// intercepted by this fixture.
    static var isEnabled: Bool {
        NSClassFromString("XCTestCase") == nil
    }

    static var data: Data? {
        json.data(using: .utf8)
    }

    static var json: String {
        template
            .replacingOccurrences(of: "%%QA_SCENE_PLACES%%", with: qaSceneInapps())
            .replacingOccurrences(of: "%%STORY_INAPPS%%", with: storyInapps())
    }

    // MARK: - QA scene places

    /// Every QA scene in the test app resolves its own place from this config, production path all
    /// the way. The feeds draw from the shared story pool below but differ in count and in the short
    /// per-place titles («Скр3», «A5»), so which place a block is showing — and whether two feeds
    /// differ — is readable right under the circles.
    private struct QAScenePlace {
        let uuid: String
        let place: String
        let label: String
        let storyCount: Int
    }

    private static let qaScenePlaces: [QAScenePlace] = [
        .init(uuid: "00000000-0000-0000-0000-000000000000", place: "stories-list-container", label: "Демо", storyCount: 16),
        .init(uuid: "aaaaaaaa-0000-4000-8000-000000000001", place: "qa-layout-error-view", label: "ВA", storyCount: 16),
        .init(uuid: "aaaaaaaa-0000-4000-8000-000000000002", place: "qa-layout-collapsing", label: "ВB", storyCount: 8),
        .init(uuid: "aaaaaaaa-0000-4000-8000-000000000003", place: "qa-layout-constrained", label: "ВC", storyCount: 12),
        .init(uuid: "aaaaaaaa-0000-4000-8000-000000000004", place: "qa-scroll", label: "Скр", storyCount: 16),
        .init(uuid: "aaaaaaaa-0000-4000-8000-000000000005", place: "qa-pager", label: "Пж", storyCount: 10),
        .init(uuid: "aaaaaaaa-0000-4000-8000-000000000006", place: "qa-list", label: "VS", storyCount: 7),
        .init(uuid: "aaaaaaaa-0000-4000-8000-000000000007", place: "qa-lazy-list", label: "LV", storyCount: 16),
        .init(uuid: "aaaaaaaa-0000-4000-8000-000000000008", place: "qa-place-first", label: "A", storyCount: 5),
        .init(uuid: "aaaaaaaa-0000-4000-8000-000000000009", place: "qa-place-second", label: "B", storyCount: 9),
        .init(uuid: "aaaaaaaa-0000-4000-8000-000000000010", place: "qa-states", label: "Сост", storyCount: 16),
        .init(uuid: "aaaaaaaa-0000-4000-8000-000000000011", place: "qa-late-delegate", label: "Дел", storyCount: 6),
        .init(uuid: "aaaaaaaa-0000-4000-8000-000000000012", place: "qa-customization", label: "Кст", storyCount: 11),
        .init(uuid: "aaaaaaaa-0000-4000-8000-000000000013", place: "qa-customization-collapsing", label: "БезЕ", storyCount: 5),
        .init(uuid: "aaaaaaaa-0000-4000-8000-000000000014", place: "qa-customization-late-error", label: "ПзЕ", storyCount: 6),
        .init(uuid: "aaaaaaaa-0000-4000-8000-000000000015", place: "qa-customization-uikit", label: "UIK", storyCount: 9),
        .init(uuid: "aaaaaaaa-0000-4000-8000-000000000016", place: "qa-rtl", label: "RTL", storyCount: 16),
        .init(uuid: "aaaaaaaa-0000-4000-8000-000000000017", place: "qa-duplicate", label: "Дбл", storyCount: 8)
    ]

    // MARK: - Story pool

    /// One pool of sixteen stories shared by every feed: the four originals keep their previews, the
    /// twelve new circles carry the gallery images. Three of the originals hold a property worth
    /// exercising by hand: №2 and №4 expire on a date, №3 has a five-second delayTime (ignored on
    /// tap by design — the tap goes through the immediate-show path).
    private struct QAStory {
        let inAppId: String
        let preview: String
        var validityDateUtc: String?
        var delayTime: String?
    }

    private static let stories: [QAStory] = [
        .init(inAppId: "11111111-1111-1111-1111-111111111111",
              preview: "https://mobpush-images.mindbox.ru/Mpush-test/409/18d0daac-574d-4c0c-a4a6-72195dc4192d.png"),
        .init(inAppId: "22222222-2222-2222-2222-222222222222",
              preview: "https://mobpush-images.mindbox.ru/Mpush-test/023044fb-3355-4d61-9179-adce1085b3b3/dc3f305a-a0fa-4539-a1a8-4276673948ca.jpg",
              validityDateUtc: "2027-01-31T23:59:59.000000Z"),
        .init(inAppId: "33333333-3333-3333-3333-333333333333",
              preview: "https://mobpush-images.mindbox.ru/Mpush-test/023044fb-3355-4d61-9179-adce1085b3b3/6918e465-8f5a-42a0-9754-1295c62c1d89.jpg",
              delayTime: "00:00:05"),
        .init(inAppId: "44444444-4444-4444-4444-444444444444",
              preview: "https://mobpush-images.mindbox.ru/Mpush-test/efa5c071-4910-4d12-87e6-a18f093f82b7/90a7aa61-bc73-4206-9463-5133bdcf781f.gif",
              validityDateUtc: "2027-06-30T23:59:59.000000Z"),
        .init(inAppId: "55555555-5555-5555-5555-555555555555",
              preview: "https://image-gallery-s3-stable.mindbox.ru/AB3DFD78626465802EBE6F3FAC42A4645656EE5BE9CB835DE4E27EFE9A9C91FA.jpeg"),
        .init(inAppId: "66666666-6666-6666-6666-666666666666",
              preview: "https://image-gallery-s3-stable.mindbox.ru/E2DC4D7DA867AA983F99B68D82536E4703981C33EAE3E62A4373501C3DCB8263.gif"),
        .init(inAppId: "77777777-7777-7777-7777-777777777777",
              preview: "https://image-gallery-s3-stable.mindbox.ru/38F6B53C6D621C90575C304362AE32AFE83DB0E04D68953E72460AF407C6C667.jpeg"),
        .init(inAppId: "88888888-8888-8888-8888-888888888888",
              preview: "https://image-gallery-s3-stable.mindbox.ru/20DC8E8E74D87D31AB0F72D360876D464AC6EE707E154596295D62078E9EE2ED.png"),
        .init(inAppId: "99999999-9999-9999-9999-999999999999",
              preview: "https://image-gallery-s3-stable.mindbox.ru/CD523BF9D1A78A600D1266FAA46CFB4A241A641F3A845A6BC810DA75E448FA4E.png"),
        .init(inAppId: "aaaaaaaa-1111-4111-8111-111111111111",
              preview: "https://image-gallery-s3-stable.mindbox.ru/79CBEC7D53BAD5609D69223F3ED914FB6928EAC6F6107B226C6EEC657945E9A4.jpeg"),
        .init(inAppId: "bbbbbbbb-2222-4222-8222-222222222222",
              preview: "https://image-gallery-s3-stable.mindbox.ru/79EA6F82B5A43223774CB4C5BA08165C9FB271039D67EA083E4E63D8E168AD5B.jpg"),
        .init(inAppId: "cccccccc-3333-4333-8333-333333333333",
              preview: "https://gallery-imgproxy.g.mindbox.ru/NMQACtBpmmdKNUwEHygJsPJq6PIU_ldZhHrC5UQs-UU/f:png/aHR0cHM6Ly9pbWFnZS1nYWxsZXJ5LXMzLXN0YWJsZS5taW5kYm94LnJ1LzRBNUFGRUFGRjg0ODM5MjNEQTk2NEJDNzg5NkYwMkQwMjgzRThCRkY5OUI1QjhGODJBMzFBRTMyMTREQUIxRDAud2VicA"),
        .init(inAppId: "dddddddd-4444-4444-8444-444444444444",
              preview: "https://image-gallery-s3-stable.mindbox.ru/F9F5734AC8506F296A1DF1CE623C02A6D845471ED4C579FB7CFB4341BF63C570.jpeg"),
        .init(inAppId: "eeeeeeee-5555-4555-8555-555555555555",
              preview: "https://image-gallery-s3-stable.mindbox.ru/42D538B84D89F7C14D963F0B0ECDC036E246878BA4B4F2260799A4E9BD889633.jpeg"),
        .init(inAppId: "ffffffff-6666-4666-8666-666666666666",
              preview: "https://image-gallery-s3-stable.mindbox.ru/48D0217513AE3384382CEB2C2F835902B61ACC001C0F130421D07AE69D74A72D.png"),
        .init(inAppId: "12121212-1212-4212-8212-121212121212",
              preview: "https://image-gallery-s3-stable.mindbox.ru/3CD9F80F82A263E1D2E3D7F28CD85A19BF9C724E2087C16337D08DD76ED19317.jpeg")
    ]

    // MARK: - Generators

    private static func qaSceneInapps() -> String {
        qaScenePlaces.map(embeddedInapp).joined(separator: ",\n")
    }

    private static func storyInapps() -> String {
        stories.map(storyInapp).joined(separator: ",\n")
    }

    private static func embeddedInapp(_ scene: QAScenePlace) -> String {
        let feed = stories.prefix(scene.storyCount).enumerated().map { index, story in
            #"""
                        {
                          "preview": "\#(story.preview)",
                          "title": "\#(scene.label)\#(index + 1)",
                          "inAppId": "\#(story.inAppId)",
                          "formId": "160477",
                          "lastChangedDateTimeUtc": "2026-08-13T09:00:00.000000Z"
                        }
            """#
        }.joined(separator: ",\n")

        return #"""
            {
              "id": "\#(scene.uuid)",
              "isPriority": false,
              "delayTime": null,
              "sdkVersion": {
                "min": 13,
                "max": null
              },
              "frequency": {
                "$type": "unlimited"
              },
              "validityPeriod": {
                "$type": "unlimited"
              },
              "displayConditions": null,
              "targeting": {
                "nodes": [
                  {
                    "$type": "true"
                  }
                ],
                "$type": "and"
              },
              "form": {
                "variants": [
                  {
                    "content": {
                      "background": {
                        "layers": [
                          {
                            "params": {
                              "stories": [
            \#(feed)
                              ]
                            },
                            "baseUrl": "https://inapp.local/stories",
                            "contentUrl": "https://mobile-static-staging.mindbox.ru/inapps/webview/content/stories.html",
                            "$type": "webview"
                          }
                        ]
                      },
                      "elements": null
                    },
                    "placeSystemName": "\#(scene.place)",
                    "$type": "embedded"
                  }
                ]
              },
              "tags": {
                "templateType": "Embedded",
                "templateSystemName": "template.dynamic.stories-feed"
              }
            }
            """#
    }

    private static func storyInapp(_ story: QAStory) -> String {
        let validity = story.validityDateUtc.map {
            #"""
            {
                    "dateTimeUtc": "\#($0)",
                    "$type": "dateTime"
                  }
            """#
        } ?? #"""
        {
                "$type": "unlimited"
              }
        """#

        return #"""
            {
              "id": "\#(story.inAppId)",
              "isPriority": false,
              "delayTime": \#(story.delayTime.map { "\"\($0)\"" } ?? "null"),
              "sdkVersion": {
                "min": 13,
                "max": null
              },
              "frequency": {
                "$type": "unlimited"
              },
              "validityPeriod": \#(validity),
              "displayConditions": {
                "$type": "directCall"
              },
              "targeting": {
                "nodes": [
                  {
                    "$type": "true"
                  }
                ],
                "$type": "and"
              },
              "form": {
                "variants": [
                  {
                    "content": {
                      "background": {
                        "layers": [
                          {
                            "params": {
                              "formId": "160477"
                            },
                            "baseUrl": "https://inapp.local/popup",
                            "contentUrl": "https://mobile-static.mindbox.ru/stable/inapps/webview/content/index.html",
                            "$type": "webview"
                          }
                        ]
                      },
                      "elements": null
                    },
                    "imageUrl": "",
                    "redirectUrl": "",
                    "intentPayload": "",
                    "$type": "modal"
                  }
                ]
              },
              "tags": {
                "templateType": "Hidden",
                "templateSystemName": "template.dynamic.onboarding"
              }
            }
            """#
    }

    // MARK: - Template

    private static let template = #"""
{
  "monitoring": {
    "logs": []
  },
  "settings": {
    "operations": {
      "viewProduct": {
        "systemName": "viewProduct"
      },
      "viewCategory": {
        "systemName": "viewCategory"
      }
    },
    "ttl": {
      "inapps": "1.00:00:00"
    },
    "slidingExpiration": {
      "config": "00:30:00",
      "pushTokenKeepalive": "14.00:00:00"
    },
    "inapp": {
      "maxInappsPerSession": 3,
      "maxInappsPerDay": 50,
      "minIntervalBetweenShows": "00:00:10"
    },
    "featureToggles": {
      "MobileSdkShouldSendInAppShowError": true,
      "MobileSdkShouldSendInAppTags": true,
      "MobileSdkShouldPrewarmInAppWebView": true,
      "MobileSdkShouldCacheInAppWebView": true
    },
    "baseAddresses": {}
  },
  "inapps": [
%%QA_SCENE_PLACES%%,
%%STORY_INAPPS%%
  ]
}
"""#
}

// swiftlint:enable all
