//
//  HomeScreenViewController.swift
//  with-thirdparty
//
//  Created by Nemi Shah on 10/11/23.
//

import UIKit
import SuperTokensIOS

class HomeScreenViewController: UIViewController {
    @IBOutlet var contentContainer: UIView!
    @IBOutlet var userIdContainer: UIView!
    @IBOutlet var userId: UILabel!
    @IBOutlet var resultView: UIView!
    @IBOutlet var resultTextField: UILabel!
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        contentContainer.layer.cornerRadius = 16
        contentContainer.clipsToBounds = true
        
        resultView.layer.cornerRadius = 16
        resultView.clipsToBounds = true
        
        do {
            let _userId = try SuperTokens.getUserId()
            userId.text = _userId
        } catch {}
        
        userIdContainer.layer.borderWidth = 1
        userIdContainer.layer.borderColor = UIColor(red: 255/255, green: 63/255, blue: 51/255, alpha: 1).cgColor
        userIdContainer.layer.cornerRadius = 8
        
        resultView.isHidden = true
    }
    
    @IBAction func callAPI() {
        resultView.isHidden = true
        var request = URLRequest(url: URL(string: Constants.apiDomain + "/sessioninfo")!)
        
        URLSession.shared.dataTask(with: request) {
            data, response, error in
            
            if data != nil {
                if let dataString: String = String(data: data!, encoding: .utf8) {
                    DispatchQueue.main.async { [weak self] in
                        self?.resultTextField.text = dataString
                        self?.resultView.isHidden = false
                    }
                }
            }
        }.resume()
    }
    
    @IBAction func signOut() {
        SuperTokens.signOut(completionHandler: { _ in
            DispatchQueue.main.async { [weak self] in
                self?.navigationController?.popViewController(animated: true)
            }
        })
    }
}
