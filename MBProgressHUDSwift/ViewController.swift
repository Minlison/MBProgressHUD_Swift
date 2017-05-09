//
//  ViewController.swift
//  MBProgressHUDSwift
//
//  Created by MinLison on 2017/4/21.
//  Copyright © 2017年 chengzivr. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

	var HUD : MBProgressHUDSwift?
	override func viewDidLoad() {
		super.viewDidLoad()
		
	}
	

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}
	@IBAction func action2(_ sender: Any) {
		let hud = MBProgressHUDSwift.show(view, animated: true)
		hud.mode = .text
		hud.bezelView.style = .solidColor
		hud.bezelView.color = UIColor.black
		hud.contentColor = UIColor.white
		hud.detailsLabel.text = "哈哈哈哈哈哈哈哈哈哈哈哈哈哈哈哈哈哈哈哈哈哈哈哈哈哈哈哈哈哈哈哈哈哈哈哈哈哈哈哈"
//		hud.detailsLabel.text = "啦啦啦啦啦"
		
//		hud.hide(true, delay: 3.0)
	}

	@IBOutlet weak var action3: UIButton!

	@IBAction func action1(_ sender: Any) {
		
	}
	@IBOutlet weak var action1: UIButton!
}

