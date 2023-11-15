//
//  ViewController.swift
//  with-thirdparty
//
//  Created by Nemi Shah on 10/11/23.
//

import UIKit
import SuperTokensIOS

class ViewController: UIViewController {
    override func viewDidAppear(_ animated: Bool) {
        if !SuperTokens.doesSessionExist() {
            self.navigationController?.pushViewController(LoginScreenViewController(nibName: "LoginView", bundle: nil), animated: true)
        } else {
            self.navigationController?.pushViewController(HomeScreenViewController(nibName: "HomeView", bundle: nil), animated: true)
        }
    }
}

