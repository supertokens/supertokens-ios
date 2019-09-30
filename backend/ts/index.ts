import * as cookieParser from 'cookie-parser';
import * as express from 'express';
import * as http from 'http';
import * as SuperTokens from 'supertokens-node-mysql-ref-jwt/express';

import login from './login';
import logout from './logout';
import refreshtoken from './refreshtoken';
import userInfo from './userInfo';
import testLogin from './testLogin';
import testUserInfo from './testUserInfo';
import testRefreshtoken from './testRefreshtoken';
import testLogout from './testLogout';
import resetConfig from './resetConfig';
import { testGetRefreshCounter } from './getRefreshTokenCounter';

let app = express();
export const defaultConfig = {
    cookie: {
        domain: "127.0.0.1",
        secure: false
    },
    mysql: {
        password: "root",
        user: "root",
        database: "auth_session",
        connectionLimit: 10000,
    },
    tokens: {
        refreshToken: {
            renewTokenPath: "/api/refreshtoken"
        },
        accessToken: {
            validity: 10
        }
    },
}
app.use(cookieParser());
SuperTokens.init(defaultConfig).then(() => {
    initRoutesAndServer();
}).catch((err: any) => {
    console.log("error while initing auth service!", err);
});

function initRoutesAndServer() {
    app.post("/api/login", function (req, res) {
        if (process.env.TEST_MODE === "testing") {
            testLogin(req, res).catch(err => {
                console.log(err);
                res.status(500).send("");
            });
        } else {
            login(req, res).catch(err => {
                console.log(err);
                res.status(500).send("");
            });
        }
        
    });

    app.get("/api/userInfo", function (req, res) {
        if (process.env.TEST_MODE === "testing") {
            testUserInfo(req, res).catch(err => {
                console.log(err);
                res.status(500).send("");
            });
        } else {
            userInfo(req, res).catch(err => {
                console.log(err);
                res.status(500).send("");
            });
        }
    });

    app.post("/api/refreshtoken", function (req, res) {
        if (process.env.TEST_MODE === "testing") {
            testRefreshtoken(req, res).catch(err => {
                console.log(err);
                res.status(500).send("");
            });
        } else {
            refreshtoken(req, res).catch(err => {
                console.log(err);
                res.status(500).send("");
            });   
        }
    });

    app.post("/api/logout", function (req, res) {
        if (process.env.TEST_MODE === "testing") {
            testLogout(req, res).catch(err => {
                console.log(err);
                res.status(500).send("");
            });
        } else {
            logout(req, res).catch(err => {
                console.log(err);
                res.status(500).send("");
            });   
        }
    });

    app.post("/api/testReset", function (req, res) {
        resetConfig(req, res).catch(err => {
            console.log(err);
            res.status(500).send("");
        });
    });

    app.get("/api/testRefreshCounter", function (req, res) {
        testGetRefreshCounter(req, res).catch(err => {
            console.log(err);
            res.status(500).send("");
        });
    });

    app.use("*", function (req, res, next) {
        res.status(404).send("Not found");
    });

    let server = http.createServer(app);
    server.listen(8080, "0.0.0.0");
}
