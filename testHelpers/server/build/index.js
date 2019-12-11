"use strict";
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : new P(function (resolve) { resolve(result.value); }).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
Object.defineProperty(exports, "__esModule", { value: true });
const cookieParser = require("cookie-parser");
const express = require("express");
const http = require("http");
const SuperTokens = require("supertokens-node");
const getRefreshTokenCounter_1 = require("./getRefreshTokenCounter");
const login_1 = require("./login");
const logout_1 = require("./logout");
const refreshtoken_1 = require("./refreshtoken");
const refreshTokenCounter_1 = require("./refreshTokenCounter");
const testHeaders_1 = require("./testHeaders");
const userInfo_1 = require("./userInfo");
const utils_1 = require("./utils");
let bodyParser = require("body-parser");
let urlencodedParser = bodyParser.urlencoded({ limit: "20mb", extended: true, parameterLimit: 20000 });
let jsonParser = bodyParser.json({ limit: "20mb" });
let app = express();
app.use(urlencodedParser);
app.use(jsonParser);
app.use(cookieParser());
SuperTokens.init([
    {
        hostname: "localhost",
        port: 9000
    }
]);
app.post("/startst", (req, res) => __awaiter(this, void 0, void 0, function* () {
    try {
        let accessTokenValidity = req.body.accessTokenValidity === undefined ? 1 : req.body.accessTokenValidity;
        yield utils_1.setKeyValueInConfig("access_token_validity", accessTokenValidity);
        let pid = yield utils_1.startST();
        res.send(pid + "");
    }
    catch (err) {
        console.log(err);
    }
}));
app.post("/beforeeach", (req, res) => __awaiter(this, void 0, void 0, function* () {
    refreshTokenCounter_1.default.resetRefreshTokenCount();
    yield utils_1.killAllST();
    yield utils_1.setupST();
    yield utils_1.setKeyValueInConfig("cookie_domain", '"127.0.0.1"');
    yield utils_1.setKeyValueInConfig("cookie_secure", "false");
    res.send();
}));
app.post("/after", (req, res) => __awaiter(this, void 0, void 0, function* () {
    yield utils_1.killAllST();
    yield utils_1.cleanST();
    res.send();
}));
app.post("/login", function (req, res) {
    login_1.default(req, res).catch(err => {
        console.log(err);
        res.status(500).send("");
    });
});
app.get("/userInfo", function (req, res) {
    userInfo_1.default(req, res).catch(err => {
        console.log(err);
        res.status(500).send("");
    });
});
app.post("/refresh", function (req, res) {
    refreshtoken_1.default(req, res).catch(err => {
        console.log(err);
        res.status(500).send("");
    });
});
app.post("/logout", function (req, res) {
    logout_1.default(req, res).catch(err => {
        console.log(err);
        res.status(500).send("");
    });
});
app.get("/refreshCounter", function (req, res) {
    getRefreshTokenCounter_1.testGetRefreshCounter(req, res).catch(err => {
        console.log(err);
        res.status(500).send("");
    });
});
app.get("/header", function (req, res) {
    testHeaders_1.testHeaders(req, res).catch(err => {
        console.log(err);
        res.status(500).send("");
    });
});
app.use("*", function (req, res, next) {
    res.status(404).send("Not found");
});
let server = http.createServer(app);
server.listen(8080, "0.0.0.0");
//# sourceMappingURL=index.js.map