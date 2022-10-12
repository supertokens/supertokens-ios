//
//  utils.swift
//  SuperTokensSession_Tests
//
//  Created by Nemi Shah on 04/10/22.
//  Copyright © 2022 CocoaPods. All rights reserved.
//

import XCTest
@testable import SuperTokensIOS

class ConfigTests: XCTestCase {
    func testShouldDoInterception() throws {
        // true cases without cookieDomain
        XCTAssertTrue(try Utils.shouldDoInterception(toCheckURL: "api.example.com", apiDomain: "https://api.example.com", cookieDomain: nil));
        XCTAssertTrue(try Utils.shouldDoInterception(toCheckURL: "http://api.example.com", apiDomain: "http://api.example.com", cookieDomain: nil));
        XCTAssertTrue(try Utils.shouldDoInterception(toCheckURL: "api.example.com", apiDomain: "http://api.example.com", cookieDomain: nil));
        XCTAssertTrue(try Utils.shouldDoInterception(toCheckURL: "https://api.example.com", apiDomain: "http://api.example.com", cookieDomain: nil));
        XCTAssertTrue(
            try Utils.shouldDoInterception(toCheckURL: "https://api.example.com:3000", apiDomain: "http://api.example.com:3000", cookieDomain: nil)
        );
        XCTAssertTrue(try Utils.shouldDoInterception(toCheckURL: "localhost:3000", apiDomain: "localhost:3000", cookieDomain: nil));
        XCTAssertTrue(try Utils.shouldDoInterception(toCheckURL: "https://localhost:3000", apiDomain: "https://localhost:3000", cookieDomain: nil));
        XCTAssertTrue(try Utils.shouldDoInterception(toCheckURL: "http://localhost:3000", apiDomain: "http://localhost:3000", cookieDomain: nil));
        XCTAssertTrue(try Utils.shouldDoInterception(toCheckURL: "localhost:3000", apiDomain: "https://localhost:3000", cookieDomain: nil));
        XCTAssertTrue(try Utils.shouldDoInterception(toCheckURL: "localhost", apiDomain: "https://localhost", cookieDomain: nil));
        XCTAssertTrue(try Utils.shouldDoInterception(toCheckURL: "http://localhost:3000", apiDomain: "https://localhost:3000", cookieDomain: nil));
        XCTAssertTrue(try Utils.shouldDoInterception(toCheckURL: "127.0.0.1:3000", apiDomain: "127.0.0.1:3000", cookieDomain: nil));
        XCTAssertTrue(try Utils.shouldDoInterception(toCheckURL: "https://127.0.0.1:3000", apiDomain: "https://127.0.0.1:3000", cookieDomain: nil));
        XCTAssertTrue(try Utils.shouldDoInterception(toCheckURL: "http://127.0.0.1:3000", apiDomain: "http://127.0.0.1:3000", cookieDomain: nil));
        XCTAssertTrue(try Utils.shouldDoInterception(toCheckURL: "127.0.0.1:3000", apiDomain: "https://127.0.0.1:3000", cookieDomain: nil));
        XCTAssertTrue(try Utils.shouldDoInterception(toCheckURL: "http://127.0.0.1:3000", apiDomain: "https://127.0.0.1:3000", cookieDomain: nil));
        XCTAssertTrue(try Utils.shouldDoInterception(toCheckURL: "http://127.0.0.1", apiDomain: "https://127.0.0.1", cookieDomain: nil));

        // true cases with cookieDomain
        XCTAssertTrue(try Utils.shouldDoInterception(toCheckURL: "api.example.com", apiDomain: "", cookieDomain: "api.example.com"));
        XCTAssertTrue(try Utils.shouldDoInterception(toCheckURL: "http://api.example.com", apiDomain: "", cookieDomain: "http://api.example.com"));
        XCTAssertTrue(try Utils.shouldDoInterception(toCheckURL: "api.example.com", apiDomain: "", cookieDomain: ".example.com"));
        XCTAssertTrue(try Utils.shouldDoInterception(toCheckURL: "https://api.example.com", apiDomain: "", cookieDomain: "http://api.example.com"));
        XCTAssertTrue(try Utils.shouldDoInterception(toCheckURL: "https://api.example.com", apiDomain: "", cookieDomain: "https://api.example.com"));
        XCTAssertTrue(try Utils.shouldDoInterception(toCheckURL: "https://sub.api.example.com", apiDomain: "", cookieDomain: ".api.example.com"));
        XCTAssertTrue(try Utils.shouldDoInterception(toCheckURL: "https://sub.api.example.com", apiDomain: "", cookieDomain: ".example.com"));
        XCTAssertTrue(try Utils.shouldDoInterception(toCheckURL: "https://sub.api.example.com:3000", apiDomain: "", cookieDomain: ".example.com:3000"));
        XCTAssertTrue(try Utils.shouldDoInterception(toCheckURL: "https://sub.api.example.com:3000", apiDomain: "", cookieDomain: ".example.com"));
        XCTAssertTrue(try Utils.shouldDoInterception(toCheckURL: "https://sub.api.example.com:3000", apiDomain: "", cookieDomain: "https://sub.api.example.com"));
        XCTAssertTrue(try Utils.shouldDoInterception(toCheckURL: "https://api.example.com:3000", apiDomain: "", cookieDomain: ".api.example.com"));
        XCTAssertTrue(try Utils.shouldDoInterception(toCheckURL: "localhost:3000", apiDomain: "", cookieDomain: "localhost:3000"));
        XCTAssertTrue(try Utils.shouldDoInterception(toCheckURL: "https://localhost:3000", apiDomain: "", cookieDomain: ".localhost:3000"));
        XCTAssertTrue(try Utils.shouldDoInterception(toCheckURL: "localhost", apiDomain: "", cookieDomain: "localhost"));
        XCTAssertTrue(try Utils.shouldDoInterception(toCheckURL: "http://a.localhost:3000", apiDomain: "", cookieDomain: ".localhost:3000"));
        XCTAssertTrue(try Utils.shouldDoInterception(toCheckURL: "127.0.0.1:3000", apiDomain: "", cookieDomain: "127.0.0.1:3000"));
        XCTAssertTrue(try Utils.shouldDoInterception(toCheckURL: "https://127.0.0.1:3000", apiDomain: "", cookieDomain: "https://127.0.0.1:3000"));
        XCTAssertTrue(try Utils.shouldDoInterception(toCheckURL: "http://127.0.0.1:3000", apiDomain: "", cookieDomain: "http://127.0.0.1:3000"));
        XCTAssertTrue(try Utils.shouldDoInterception(toCheckURL: "127.0.0.1:3000", apiDomain: "", cookieDomain: "https://127.0.0.1:3000"));
        XCTAssertTrue(try Utils.shouldDoInterception(toCheckURL: "http://127.0.0.1:3000", apiDomain: "", cookieDomain: "https://127.0.0.1:3000"));
        XCTAssertTrue(try Utils.shouldDoInterception(toCheckURL: "http://127.0.0.1", apiDomain: "", cookieDomain: "https://127.0.0.1"));
        XCTAssertTrue(try Utils.shouldDoInterception(toCheckURL: "https://sub.api.example.com:3000", apiDomain: "", cookieDomain: ".com"));
        XCTAssertTrue(try Utils.shouldDoInterception(toCheckURL: "https://sub.api.example.co.uk:3000", apiDomain: "", cookieDomain: ".api.example.co.uk"));
        XCTAssertTrue(try Utils.shouldDoInterception(toCheckURL: "https://sub1.api.example.co.uk:3000", apiDomain: "", cookieDomain: ".api.example.co.uk"));
        XCTAssertTrue(try Utils.shouldDoInterception(toCheckURL: "https://api.example.co.uk:3000", apiDomain: "", cookieDomain: ".api.example.co.uk"));
        XCTAssertTrue(try Utils.shouldDoInterception(toCheckURL: "https://api.example.co.uk:3000", apiDomain: "", cookieDomain: "api.example.co.uk"));

        // false cases with api
        XCTAssertTrue(!(try Utils.shouldDoInterception(toCheckURL: "localhost:3001", apiDomain: "localhost:3000", cookieDomain: nil)));
        XCTAssertTrue(!(try Utils.shouldDoInterception(toCheckURL: "localhost:3001", apiDomain: "example.com", cookieDomain: nil)));
        XCTAssertTrue(!(try Utils.shouldDoInterception(toCheckURL: "localhost:3001", apiDomain: "localhost", cookieDomain: nil)));
        XCTAssertTrue(!(try Utils.shouldDoInterception(toCheckURL: "https://example.com", apiDomain: "https://api.example.com", cookieDomain: nil)));
        XCTAssertTrue(!(try Utils.shouldDoInterception(toCheckURL: "https://api.example.com", apiDomain: "https://a.api.example.com", cookieDomain: nil)));
        XCTAssertTrue(!(try Utils.shouldDoInterception(toCheckURL: "https://api.example.com", apiDomain: "https://example.com", cookieDomain: nil)));
        XCTAssertTrue(!(try Utils.shouldDoInterception(toCheckURL: "https://example.com:3001", apiDomain: "https://api.example.com:3001", cookieDomain: nil)));
        XCTAssertTrue(
            !(try Utils.shouldDoInterception(toCheckURL: "https://api.example.com:3002", apiDomain: "https://api.example.com:3001", cookieDomain: nil))
            );

        // false cases with cookieDomain
        XCTAssertTrue(!(try Utils.shouldDoInterception(toCheckURL: "https://sub.api.example.com:3000", apiDomain: "", cookieDomain: ".example.com:3001")));
        XCTAssertTrue(!(try Utils.shouldDoInterception(toCheckURL: "https://sub.api.example.com:3000", apiDomain: "", cookieDomain: "example.com")));
        XCTAssertTrue(!(try Utils.shouldDoInterception(toCheckURL: "https://api.example.com:3000", apiDomain: "", cookieDomain: ".a.api.example.com")));
        XCTAssertTrue(!(try Utils.shouldDoInterception(toCheckURL: "https://sub.api.example.com:3000", apiDomain: "", cookieDomain: "localhost")));
        XCTAssertTrue(!(try Utils.shouldDoInterception(toCheckURL: "http://127.0.0.1:3000", apiDomain: "", cookieDomain: "https://127.0.0.1:3010")));
        XCTAssertTrue(!(try Utils.shouldDoInterception(toCheckURL: "https://sub.api.example.co.uk:3000", apiDomain: "", cookieDomain: "api.example.co.uk")));
        XCTAssertTrue(!(try Utils.shouldDoInterception(toCheckURL: "https://sub.api.example.co.uk", apiDomain: "", cookieDomain: "api.example.co.uk")));

        // errors in input
        do {
            _ = try Utils.shouldDoInterception(toCheckURL: "/some/path", apiDomain: "", cookieDomain: "api.example.co.uk")
            XCTFail("shouldDoInterception worked when it should have thrown")
        } catch SuperTokensError.initError(let message) {
            XCTAssertEqual(message, "Please provide a valid domain name")
        } catch {
            XCTFail("Unexpected error")
        }
        
        do {
            _ = try Utils.shouldDoInterception(toCheckURL: "/some/path", apiDomain: "api.example.co.uk", cookieDomain: nil)
            XCTFail("shouldDoInterception worked when it should have thrown")
        } catch SuperTokensError.initError(let message) {
            XCTAssertEqual(message, "Please provide a valid domain name")
        } catch {
            XCTFail("Unexpected error")
        }
    }
    
    func testSessionScopeNormalisation() throws {
        XCTAssertEqual(try NormalisedInputType.normaliseSessionScopeOrThrowError(sessionScope: "api.example.com") , "api.example.com");
        XCTAssertEqual(try NormalisedInputType.normaliseSessionScopeOrThrowError(sessionScope: "http://api.example.com") , "api.example.com");
        XCTAssertEqual(try NormalisedInputType.normaliseSessionScopeOrThrowError(sessionScope: "https://api.example.com") , "api.example.com");
        XCTAssertEqual(try NormalisedInputType.normaliseSessionScopeOrThrowError(sessionScope: "http://api.example.com?hello=1") , "api.example.com");
        XCTAssertEqual(try NormalisedInputType.normaliseSessionScopeOrThrowError(sessionScope: "http://api.example.com/hello") , "api.example.com");
        XCTAssertEqual(try NormalisedInputType.normaliseSessionScopeOrThrowError(sessionScope: "http://api.example.com/") , "api.example.com");
        XCTAssertEqual(try NormalisedInputType.normaliseSessionScopeOrThrowError(sessionScope: "http://api.example.com:8080") , "api.example.com");
        XCTAssertEqual(try NormalisedInputType.normaliseSessionScopeOrThrowError(sessionScope: "http://api.example.com#random2") , "api.example.com");
        XCTAssertEqual(try NormalisedInputType.normaliseSessionScopeOrThrowError(sessionScope: "api.example.com/") , "api.example.com");
        XCTAssertEqual(try NormalisedInputType.normaliseSessionScopeOrThrowError(sessionScope: "api.example.com#random") , "api.example.com");
        XCTAssertEqual(try NormalisedInputType.normaliseSessionScopeOrThrowError(sessionScope: "example.com") , "example.com");
        XCTAssertEqual(try NormalisedInputType.normaliseSessionScopeOrThrowError(sessionScope: "api.example.com/?hello=1&bye=2") , "api.example.com");
        XCTAssertEqual(try NormalisedInputType.normaliseSessionScopeOrThrowError(sessionScope: "localhost") , "localhost");
        XCTAssertEqual(try NormalisedInputType.normaliseSessionScopeOrThrowError(sessionScope: "localhost:8080") , "localhost");
        XCTAssertEqual(try NormalisedInputType.normaliseSessionScopeOrThrowError(sessionScope: "localhost.org") , "localhost.org");
        XCTAssertEqual(try NormalisedInputType.normaliseSessionScopeOrThrowError(sessionScope: "127.0.0.1") , "127.0.0.1");

        XCTAssertEqual(try NormalisedInputType.normaliseSessionScopeOrThrowError(sessionScope: ".api.example.com") , ".api.example.com");
        XCTAssertEqual(try NormalisedInputType.normaliseSessionScopeOrThrowError(sessionScope: ".api.example.com/") , ".api.example.com");
        XCTAssertEqual(try NormalisedInputType.normaliseSessionScopeOrThrowError(sessionScope: ".api.example.com#random") , ".api.example.com");
        XCTAssertEqual(try NormalisedInputType.normaliseSessionScopeOrThrowError(sessionScope: ".example.com") , ".example.com");
        XCTAssertEqual(try NormalisedInputType.normaliseSessionScopeOrThrowError(sessionScope: ".api.example.com/?hello=1&bye=2") , ".api.example.com");
        XCTAssertEqual(try NormalisedInputType.normaliseSessionScopeOrThrowError(sessionScope: ".localhost") , "localhost");
        XCTAssertEqual(try NormalisedInputType.normaliseSessionScopeOrThrowError(sessionScope: ".localhost:8080") , "localhost");
        XCTAssertEqual(try NormalisedInputType.normaliseSessionScopeOrThrowError(sessionScope: ".localhost.org") , ".localhost.org");
        XCTAssertEqual(try NormalisedInputType.normaliseSessionScopeOrThrowError(sessionScope: ".127.0.0.1") , "127.0.0.1");
        
        do {
            _ = try NormalisedInputType.normaliseSessionScopeOrThrowError(sessionScope: "http://");
            XCTFail("Session scope normalising passed when it shouldnt")
        } catch SuperTokensError.initError(let message) {
            XCTAssertEqual(message, "Please provide a valid sessionScope")
        } catch {
            XCTFail("Unexpected error")
        }
    }
    
    func testURLPathNormalisation() throws {
        XCTAssertEqual(try NormalisedURLPath.normaliseURLPathOrThrowError(input: "exists?email=john.doe%40gmail.com"), "/exists");
        XCTAssertEqual(
            try NormalisedURLPath.normaliseURLPathOrThrowError(input: "/auth/email/exists?email=john.doe%40gmail.com"),
            "/auth/email/exists"
        );
        XCTAssertEqual(try NormalisedURLPath.normaliseURLPathOrThrowError(input: "exists"), "/exists");
        XCTAssertEqual(try NormalisedURLPath.normaliseURLPathOrThrowError(input: "/exists"), "/exists");
        XCTAssertEqual(try NormalisedURLPath.normaliseURLPathOrThrowError(input: "/exists?email=john.doe%40gmail.com"), "/exists");
        XCTAssertEqual(try NormalisedURLPath.normaliseURLPathOrThrowError(input: "http://api.example.com"), "");
        XCTAssertEqual(try NormalisedURLPath.normaliseURLPathOrThrowError(input: "https://api.example.com"), "");
        XCTAssertEqual(try NormalisedURLPath.normaliseURLPathOrThrowError(input: "http://api.example.com?hello=1"), "");
        XCTAssertEqual(try NormalisedURLPath.normaliseURLPathOrThrowError(input: "http://api.example.com/hello"), "/hello");
        XCTAssertEqual(try NormalisedURLPath.normaliseURLPathOrThrowError(input: "http://api.example.com/"), "");
        XCTAssertEqual(try NormalisedURLPath.normaliseURLPathOrThrowError(input: "http://api.example.com:8080"), "");
        XCTAssertEqual(try NormalisedURLPath.normaliseURLPathOrThrowError(input: "http://api.example.com#random2"), "");
        XCTAssertEqual(try NormalisedURLPath.normaliseURLPathOrThrowError(input: "api.example.com/"), "");
        XCTAssertEqual(try NormalisedURLPath.normaliseURLPathOrThrowError(input: "api.example.com#random"), "");
        XCTAssertEqual(try NormalisedURLPath.normaliseURLPathOrThrowError(input: ".example.com"), "");
        XCTAssertEqual(try NormalisedURLPath.normaliseURLPathOrThrowError(input: "api.example.com/?hello=1&bye=2"), "");

        XCTAssertEqual(try NormalisedURLPath.normaliseURLPathOrThrowError(input: "http://api.example.com/one/two"), "/one/two");
        XCTAssertEqual(try NormalisedURLPath.normaliseURLPathOrThrowError(input: "http://1.2.3.4/one/two"), "/one/two");
        XCTAssertEqual(try NormalisedURLPath.normaliseURLPathOrThrowError(input: "1.2.3.4/one/two"), "/one/two");
        XCTAssertEqual(try NormalisedURLPath.normaliseURLPathOrThrowError(input: "https://api.example.com/one/two/"), "/one/two");
        XCTAssertEqual(try NormalisedURLPath.normaliseURLPathOrThrowError(input: "http://api.example.com/one/two?hello=1"), "/one/two");
        XCTAssertEqual(try NormalisedURLPath.normaliseURLPathOrThrowError(input: "http://api.example.com/hello/"), "/hello");
        XCTAssertEqual(try NormalisedURLPath.normaliseURLPathOrThrowError(input: "http://api.example.com/one/two/"), "/one/two");
        XCTAssertEqual(try NormalisedURLPath.normaliseURLPathOrThrowError(input: "http://api.example.com:8080/one/two"), "/one/two");
        XCTAssertEqual(try NormalisedURLPath.normaliseURLPathOrThrowError(input: "http://api.example.com/one/two#random2"), "/one/two");
        XCTAssertEqual(try NormalisedURLPath.normaliseURLPathOrThrowError(input: "api.example.com/one/two"), "/one/two");
        XCTAssertEqual(try NormalisedURLPath.normaliseURLPathOrThrowError(input: "api.example.com/one/two/#random"), "/one/two");
        XCTAssertEqual(try NormalisedURLPath.normaliseURLPathOrThrowError(input: ".example.com/one/two"), "/one/two");
        XCTAssertEqual(try NormalisedURLPath.normaliseURLPathOrThrowError(input: "api.example.com/one/two?hello=1&bye=2"), "/one/two");

        XCTAssertEqual(try NormalisedURLPath.normaliseURLPathOrThrowError(input: "/one/two"), "/one/two");
        XCTAssertEqual(try NormalisedURLPath.normaliseURLPathOrThrowError(input: "one/two"), "/one/two");
        XCTAssertEqual(try NormalisedURLPath.normaliseURLPathOrThrowError(input: "one/two/"), "/one/two");
        XCTAssertEqual(try NormalisedURLPath.normaliseURLPathOrThrowError(input: "/one"), "/one");
        XCTAssertEqual(try NormalisedURLPath.normaliseURLPathOrThrowError(input: "one"), "/one");
        XCTAssertEqual(try NormalisedURLPath.normaliseURLPathOrThrowError(input: "one/"), "/one");
        XCTAssertEqual(try NormalisedURLPath.normaliseURLPathOrThrowError(input: "/one/two/"), "/one/two");
        XCTAssertEqual(try NormalisedURLPath.normaliseURLPathOrThrowError(input: "/one/two?hello=1"), "/one/two");
        XCTAssertEqual(try NormalisedURLPath.normaliseURLPathOrThrowError(input: "one/two?hello=1"), "/one/two");
        XCTAssertEqual(try NormalisedURLPath.normaliseURLPathOrThrowError(input: "/one/two/#random"), "/one/two");
        XCTAssertEqual(try NormalisedURLPath.normaliseURLPathOrThrowError(input: "one/two#random"), "/one/two");

        XCTAssertEqual(try NormalisedURLPath.normaliseURLPathOrThrowError(input: "localhost:4000/one/two"), "/one/two");
        XCTAssertEqual(try NormalisedURLPath.normaliseURLPathOrThrowError(input: "127.0.0.1:4000/one/two"), "/one/two");
        XCTAssertEqual(try NormalisedURLPath.normaliseURLPathOrThrowError(input: "127.0.0.1/one/two"), "/one/two");
        XCTAssertEqual(try NormalisedURLPath.normaliseURLPathOrThrowError(input: "https://127.0.0.1:80/one/two"), "/one/two");
        XCTAssertEqual(try NormalisedURLPath.normaliseURLPathOrThrowError(input: "/"), "");

        XCTAssertEqual(try NormalisedURLPath.normaliseURLPathOrThrowError(input: "/.netlify/functions/api"), "/.netlify/functions/api");
        XCTAssertEqual(try NormalisedURLPath.normaliseURLPathOrThrowError(input: "/netlify/.functions/api"), "/netlify/.functions/api");
        XCTAssertEqual(
            try NormalisedURLPath.normaliseURLPathOrThrowError(input: "app.example.com/.netlify/functions/api"),
            "/.netlify/functions/api"
        );
        XCTAssertEqual(
            try NormalisedURLPath.normaliseURLPathOrThrowError(input: "app.example.com/netlify/.functions/api"),
            "/netlify/.functions/api"
        );
        XCTAssertEqual(try NormalisedURLPath.normaliseURLPathOrThrowError(input: "/app.example.com"), "/app.example.com");
    }
    
    func testURLDomainNormalisation() throws {
        XCTAssertEqual(try NormalisedURLDomain.normaliseUrlDomainOrThrowError(input: "http://api.example.com") , "http://api.example.com");
        XCTAssertEqual(try NormalisedURLDomain.normaliseUrlDomainOrThrowError(input: "https://api.example.com") , "https://api.example.com");
        XCTAssertEqual(try NormalisedURLDomain.normaliseUrlDomainOrThrowError(input: "http://api.example.com?hello=1") , "http://api.example.com");
        XCTAssertEqual(try NormalisedURLDomain.normaliseUrlDomainOrThrowError(input: "http://api.example.com/hello") , "http://api.example.com");
        XCTAssertEqual(try NormalisedURLDomain.normaliseUrlDomainOrThrowError(input: "http://api.example.com/") , "http://api.example.com");
        XCTAssertEqual(try NormalisedURLDomain.normaliseUrlDomainOrThrowError(input: "http://api.example.com:8080") , "http://api.example.com:8080");
        XCTAssertEqual(try NormalisedURLDomain.normaliseUrlDomainOrThrowError(input: "http://api.example.com#random2") , "http://api.example.com");
        XCTAssertEqual(try NormalisedURLDomain.normaliseUrlDomainOrThrowError(input: "api.example.com/") , "https://api.example.com");
        XCTAssertEqual(try NormalisedURLDomain.normaliseUrlDomainOrThrowError(input: "api.example.com") , "https://api.example.com");
        XCTAssertEqual(try NormalisedURLDomain.normaliseUrlDomainOrThrowError(input: "api.example.com#random") , "https://api.example.com");
        XCTAssertEqual(try NormalisedURLDomain.normaliseUrlDomainOrThrowError(input: ".example.com") , "https://example.com");
        XCTAssertEqual(try NormalisedURLDomain.normaliseUrlDomainOrThrowError(input: "api.example.com/?hello=1&bye=2") , "https://api.example.com");
        XCTAssertEqual(try NormalisedURLDomain.normaliseUrlDomainOrThrowError(input: "localhost") , "http://localhost");
        XCTAssertEqual(try NormalisedURLDomain.normaliseUrlDomainOrThrowError(input: "https://localhost") , "https://localhost");

        XCTAssertEqual(try NormalisedURLDomain.normaliseUrlDomainOrThrowError(input: "http://api.example.com/one/two") , "http://api.example.com");
        XCTAssertEqual(try NormalisedURLDomain.normaliseUrlDomainOrThrowError(input: "http://1.2.3.4/one/two") , "http://1.2.3.4");
        XCTAssertEqual(try NormalisedURLDomain.normaliseUrlDomainOrThrowError(input: "https://1.2.3.4/one/two") , "https://1.2.3.4");
        XCTAssertEqual(try NormalisedURLDomain.normaliseUrlDomainOrThrowError(input: "1.2.3.4/one/two") , "http://1.2.3.4");
        XCTAssertEqual(try NormalisedURLDomain.normaliseUrlDomainOrThrowError(input: "https://api.example.com/one/two/") , "https://api.example.com");
        XCTAssertEqual(try NormalisedURLDomain.normaliseUrlDomainOrThrowError(input: "http://api.example.com/one/two?hello=1") , "http://api.example.com");
        XCTAssertEqual(try NormalisedURLDomain.normaliseUrlDomainOrThrowError(input: "http://api.example.com/one/two#random2") , "http://api.example.com");
        XCTAssertEqual(try NormalisedURLDomain.normaliseUrlDomainOrThrowError(input: "api.example.com/one/two") , "https://api.example.com");
        XCTAssertEqual(try NormalisedURLDomain.normaliseUrlDomainOrThrowError(input: "api.example.com/one/two/#random") , "https://api.example.com");
        XCTAssertEqual(try NormalisedURLDomain.normaliseUrlDomainOrThrowError(input: ".example.com/one/two") , "https://example.com");
        XCTAssertEqual(try NormalisedURLDomain.normaliseUrlDomainOrThrowError(input: "localhost:4000") , "http://localhost:4000");
        XCTAssertEqual(try NormalisedURLDomain.normaliseUrlDomainOrThrowError(input: "127.0.0.1:4000") , "http://127.0.0.1:4000");
        XCTAssertEqual(try NormalisedURLDomain.normaliseUrlDomainOrThrowError(input: "127.0.0.1") , "http://127.0.0.1");
        XCTAssertEqual(try NormalisedURLDomain.normaliseUrlDomainOrThrowError(input: "https://127.0.0.1:80/") , "https://127.0.0.1:80");
        XCTAssertEqual(try NormalisedURLDomain.normaliseUrlDomainOrThrowError(input: "http://localhost.org:8080") , "http://localhost.org:8080");
        
        do {
            _ = try NormalisedURLDomain.normaliseUrlDomainOrThrowError(input: "/one/two");
            XCTFail("URL normalisation passed when it should have failed")
        } catch SuperTokensError.initError(let message) {
            XCTAssertEqual(message, "Please provide a valid domain name")
        } catch {
            XCTFail("Unexpected Error")
        }
        
        do {
            _ = try NormalisedURLDomain.normaliseUrlDomainOrThrowError(input: "/.netlify/functions/api");
            XCTFail("URL normalisation passed when it should have failed")
        } catch SuperTokensError.initError(let message) {
            XCTAssertEqual(message, "Please provide a valid domain name")
        } catch {
            XCTFail("Unexpected Error")
        }
    }
    
    func testVariousInputConfigs() throws {
        try SuperTokens.initialize(
            apiDomain: "example.com",
            apiBasePath: "/"
        );
        XCTAssertEqual(SuperTokens.refreshTokenUrl , "https://example.com/session/refresh");
        XCTAssertEqual(SuperTokens.config!.apiDomain , "https://example.com");

        SuperTokens.resetForTests()
        try SuperTokens.initialize(
            apiDomain: "https://api.example.com",
            apiBasePath: "/some/path/"
        );
        XCTAssertEqual(SuperTokens.refreshTokenUrl , "https://api.example.com/some/path/session/refresh");
        XCTAssertEqual(SuperTokens.config!.apiDomain , "https://api.example.com");

        SuperTokens.resetForTests()
        try SuperTokens.initialize(
            apiDomain: "localhost",
            apiBasePath: "/some/path/"
        );
        XCTAssertEqual(SuperTokens.refreshTokenUrl , "http://localhost/some/path/session/refresh");
        XCTAssertEqual(SuperTokens.config!.apiDomain , "http://localhost");

        SuperTokens.resetForTests()
        try SuperTokens.initialize(
            apiDomain: "localhost:9000",
            apiBasePath: "/some/path/"
        );
        XCTAssertEqual(SuperTokens.refreshTokenUrl , "http://localhost:9000/some/path/session/refresh");
        XCTAssertEqual(SuperTokens.config!.apiDomain , "http://localhost:9000");

        SuperTokens.resetForTests()
        try SuperTokens.initialize(
            apiDomain: "https://localhost:9000",
            apiBasePath: "/some/path/"
        );
        XCTAssertEqual(SuperTokens.refreshTokenUrl , "https://localhost:9000/some/path/session/refresh");
        XCTAssertEqual(SuperTokens.config!.apiDomain , "https://localhost:9000");

        SuperTokens.resetForTests()
        try SuperTokens.initialize(
            apiDomain: "example.com",
            apiBasePath: "/some/path/",
            sessionExpiredStatusCode: 402
        );
        XCTAssertEqual(SuperTokens.refreshTokenUrl , "https://example.com/some/path/session/refresh");
        XCTAssertEqual(SuperTokens.config!.sessionExpiredStatusCode , 402);

        SuperTokens.resetForTests()
        try SuperTokens.initialize(
            apiDomain: "example.com"
        );
        XCTAssertEqual(SuperTokens.refreshTokenUrl , "https://example.com/auth/session/refresh");
        XCTAssertEqual(SuperTokens.config!.cookieDomain , nil);

        SuperTokens.resetForTests()
        try SuperTokens.initialize(
            apiDomain: "example.com",
            cookieDomain: "a.b.example.com"
        );
        XCTAssertEqual(SuperTokens.refreshTokenUrl , "https://example.com/auth/session/refresh");
        XCTAssertEqual(SuperTokens.config!.cookieDomain , "a.b.example.com");
    }
}
