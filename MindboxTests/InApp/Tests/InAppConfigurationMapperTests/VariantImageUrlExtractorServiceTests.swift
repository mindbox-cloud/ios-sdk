//
//  VariantImageUrlExtractorServiceTests.swift
//  MindboxTests
//
//  Created by vailence on 04.09.2023.
//  Copyright © 2023 Mindbox. All rights reserved.
//

import XCTest
@testable import Mindbox

final class VariantImageUrlExtractorServiceTests: XCTestCase {
    
    var sut: VariantImageUrlExtractorServiceProtocol!
    
    override func setUp() {
        super.setUp()
        sut = VariantImageUrlExtractorService()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    func decodeJSON<T: Decodable>(_ json: String, to type: T.Type) -> T? {
            guard let data = json.data(using: .utf8) else { return nil }
            let decoder = JSONDecoder()
            do {
                let decodedObject = try decoder.decode(T.self, from: data)
                return decodedObject
            } catch {
                print("JSON Decoding Error: \(error)")
                return nil
            }
        }
        
    func testExtractUrls_modal_all_valid() {
        let formVariantJSON = """
        {
            "content": {
                "background": {
                    "layers": [
                        {
                            "action": {
                                "intentPayload": "{}",
                                "value": "https://images.pexels.com/photos/1624496/pexels-photo-1624496.jpeg",
                                "$type": "redirectUrl"
                            },
                            "source": {
                                "value": "https://images.pexels.com/photos/1624496/pexels-photo-1624496.jpeg",
                                "$type": "url"
                            },
                            "$type": "image"
                        },
                        {
                            "action": {
                                "intentPayload": "{}",
                                "value": "https://mindbox-pushok.umbrellait.tech:444/?image=mindbox.png&broken=true&error=wait&speed=20",
                                "$type": "redirectUrl"
                            },
                            "source": {
                                "value": "https://mindbox-pushok.umbrellait.tech:444/?image=mindbox.png&broken=true&error=wait&speed=20",
                                "$type": "url"
                            },
                            "$type": "image"
                        }
                    ]
                },
                "position": {
                    "margin": {
                        "kind": "dp",
                        "top": 0,
                        "right": 0,
                        "left": 0,
                        "bottom": 0
                    },
                    "gravity": {
                        "horizontal": "center",
                        "vertical": "bottom"
                    }
                },
                "elements": [
                    {
                        "color": "#000000",
                        "lineWidth": 1,
                        "size": {
                            "kind": "dp",
                            "width": 24,
                            "height": 24
                        },
                        "position": {
                            "margin": {
                                "kind": "proportion",
                                "top": 0.02,
                                "right": 0.02,
                                "left": 0,
                                "bottom": 0
                            }
                        },
                        "$type": "closeButton"
                    }
                ]
            },
            "imageUrl": "",
            "redirectUrl": "",
            "intentPayload": "",
            "$type": "modal"
        }
        """
        
        guard let formVariant: MindboxFormVariant = decodeJSON(formVariantJSON, to: MindboxFormVariant.self) else {
            XCTFail("Could not decode MindboxFormVariant from JSON")
            return
        }
        
        let extractedUrls = sut.extractImageURL(from: formVariant)
        let expectedUrls = [
            "https://images.pexels.com/photos/1624496/pexels-photo-1624496.jpeg",
            "https://mindbox-pushok.umbrellait.tech:444/?image=mindbox.png&broken=true&error=wait&speed=20",
        ]
        
        XCTAssertEqual(extractedUrls, expectedUrls)
    }
    
    func testExtractUrls_snackbar_all_valid() {
        let formVariantJSON = """
        {
            "content": {
                "background": {
                    "layers": [
                        {
                            "action": {
                                "intentPayload": "{}",
                                "value": "https://www.getmailbird.com/setup/assets/imgs/logos/gmail.com.webp",
                                "$type": "redirectUrl"
                            },
                            "source": {
                                "value": "https://www.getmailbird.com/setup/assets/imgs/logos/gmail.com.webp",
                                "$type": "url"
                            },
                            "$type": "image"
                        },
                        {
                            "action": {
                                "intentPayload": "{}",
                                "value": "https://images.pexels.com/photos/1402787/pexels-photo-1402787.jpeg?auto=compress&cs=tinysrgb&w=6000&h=4000&dpr=2",
                                "$type": "redirectUrl"
                            },
                            "source": {
                                "value": "https://images.pexels.com/photos/1402787/pexels-photo-1402787.jpeg?auto=compress&cs=tinysrgb&w=6000&h=4000&dpr=2",
                                "$type": "url"
                            },
                            "$type": "image"
                        }
                    ]
                },
                "position": {
                    "margin": {
                        "kind": "dp",
                        "top": 0,
                        "right": 0,
                        "left": 0,
                        "bottom": 0
                    },
                    "gravity": {
                        "horizontal": "center",
                        "vertical": "bottom"
                    }
                },
                "elements": [
                    {
                        "color": "#000000",
                        "lineWidth": 1,
                        "size": {
                            "kind": "dp",
                            "width": 24,
                            "height": 24
                        },
                        "position": {
                            "margin": {
                                "kind": "proportion",
                                "top": 0.02,
                                "right": 0.02,
                                "left": 0,
                                "bottom": 0
                            }
                        },
                        "$type": "closeButton"
                    }
                ]
            },
            "imageUrl": "",
            "redirectUrl": "",
            "intentPayload": "",
            "$type": "snackbar"
        }
        """
        
        guard let formVariant: MindboxFormVariant = decodeJSON(formVariantJSON, to: MindboxFormVariant.self) else {
            XCTFail("Could not decode MindboxFormVariant from JSON")
            return
        }
        
        let extractedUrls = sut.extractImageURL(from: formVariant)
        let expectedUrls = [
            "https://www.getmailbird.com/setup/assets/imgs/logos/gmail.com.webp",
            "https://images.pexels.com/photos/1402787/pexels-photo-1402787.jpeg?auto=compress&cs=tinysrgb&w=6000&h=4000&dpr=2",
        ]
        
        XCTAssertEqual(extractedUrls, expectedUrls)
    }
}
