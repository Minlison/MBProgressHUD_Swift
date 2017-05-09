//
//  MBProgressHUDSwift.swift
//  MBProgressHUDSwift
//
//  Created by MinLison on 2017/4/21.
//  Copyright © 2017年 chengzivr. All rights reserved.
//

import UIKit

//MARK: - ENUM
enum MBProgressHUDSwiftMode: Int {
	case indeterminate = 0
	case customView
	case text
}

enum MBProgressHUDSwiftAnimation: Int {
	case fade = 0
	case zoom
	case zoomOut
	case zoomIn
}
enum MBProgressHUDSwiftBackgroundStyle : Int {
	case solidColor
	case blur
}


fileprivate let MBProgressMaxOffset : CGFloat = 1000000
fileprivate let MBDefaultPadding : CGFloat = 4
fileprivate let MBDefaultLabelFontSize : CGFloat = 16
fileprivate let MBDefaultDetailsLabelFontSize : CGFloat = 14

extension MBProgressHUDSwift {
	
	/**
	* Creates a new HUD, adds it to provided view and shows it. The counterpart to this method is hideHUDForView:animated:.
	*
	* @note This method sets removeFromSuperViewOnHide. The HUD will automatically be removed from the view hierarchy when hidden.
	*
	* @param view The view that the HUD will be added to
	* @param animated If set to YES the HUD will appear using the current animationType. If set to NO the HUD will not use
	* animations while appearing.
	* @return A reference to the created HUD.
	*
	* @see hideHUDForView:animated:
	* @see animationType
	*/
	class func show(_ addToView: UIView, animated: Bool) -> MBProgressHUDSwift {
		let hud = MBProgressHUDSwift(addToView)
		hud.removeFromSuperViewOnHide = true
		addToView.addSubview(hud)
		hud.show(animated)
		return hud
	}
	/**
	* Finds the top-most HUD subview and hides it. The counterpart to this method is showHUDAddedTo:animated:.
	*
	* @note This method sets removeFromSuperViewOnHide. The HUD will automatically be removed from the view hierarchy when hidden.
	*
	* @param view The view that is going to be searched for a HUD subview.
	* @param animated If set to YES the HUD will disappear using the current animationType. If set to NO the HUD will not use
	* animations while disappearing.
	* @return YES if a HUD was found and removed, NO otherwise.
	*
	* @see showHUDAddedTo:animated:
	* @see animationType
	*/
	class func hide(_ forView: UIView, animated: Bool) -> Bool {
		if let hud = HUD(forView) {
			hud.removeFromSuperViewOnHide = true
			hud.hide(animated)
			return true
		}
		return false
	}
	/**
	* Finds the top-most HUD subview and returns it.
	*
	* @param view The view that is going to be searched.
	* @return A reference to the last HUD subview discovered.
	*/
	class func HUD(_ forView: UIView) -> MBProgressHUDSwift? {
		for view in forView.subviews {
			if view is MBProgressHUDSwift {
				return view as? MBProgressHUDSwift
			}
		}
		return nil
	}
	/**
	* Displays the HUD.
	*
	* @note You need to make sure that the main thread completes its run loop soon after this method call so that
	* the user interface can be updated. Call this method when your task is already set up to be executed in a new thread
	* (e.g., when using something like NSOperation or making an asynchronous call like NSURLRequest).
	*
	* @param animated If set to YES the HUD will appear using the current animationType. If set to NO the HUD will not use
	* animations while appearing.
	*
	* @see animationType
	*/
	func show(_ animated: Bool) {
		minShowTimer?.invalidate()
		useAnimation = animated
		isFinished = false
		if graceTime > 0 {
			let timer = Timer(timeInterval: graceTime, target: self, selector: #selector(handleGraceTimer(_:)), userInfo: nil, repeats: false)
			RunLoop.main.add(timer, forMode: .commonModes)
			graceTimer = timer
		} else {
			showUsingAnimation(animated)
		}
		
	}
	/**
	* Hides the HUD. This still calls the hudWasHidden: delegate. This is the counterpart of the show: method. Use it to
	* hide the HUD when your task completes.
	*
	* @param animated If set to YES the HUD will disappear using the current animationType. If set to NO the HUD will not use
	* animations while disappearing.
	*
	* @see animationType
	*/
	func hide(_ animated: Bool) {
		graceTimer?.invalidate()
		useAnimation = animated
		isFinished = true
		
		if minShowTime > 0 , let showStarted = showStarted {
			let interv = Date().timeIntervalSince(showStarted)
			if interv < minShowTime {
				let timer = Timer(timeInterval: (minShowTime - interv), target: self, selector: #selector(handleMinShowTimer(_:)), userInfo: nil, repeats: false)
				RunLoop.main.add(timer, forMode: .commonModes)
				minShowTimer = timer
				return
			}
		}
		hideUsingAnimation(animated)
	}
	
	/**
	* Hides the HUD after a delay. This still calls the hudWasHidden: delegate. This is the counterpart of the show: method. Use it to
	* hide the HUD when your task completes.
	*
	* @param animated If set to YES the HUD will disappear using the current animationType. If set to NO the HUD will not use
	* animations while disappearing.
	* @param delay Delay in seconds until the HUD is hidden.
	*
	* @see animationType
	*/
	func hide(_ animated: Bool, delay: TimeInterval) {
		let timer = Timer(timeInterval: delay, target: self, selector: #selector(handleHideTimer(_:)), userInfo: animated, repeats: false)
		RunLoop.main.add(timer, forMode: .commonModes)
		hideDelayTimer = timer
	}
	
	
	
}

class MBProgressHUDSwift: UIView {
	
	///  * Grace period is the time (in seconds) that the invoked method may be run without
	/// * showing the HUD. If the task finishes before the grace time runs out, the HUD will
	/// * not be shown at all.
	/// * This may be used to prevent HUD display for very short tasks.
	/// * Defaults to 0 (no grace time).
	var graceTime : TimeInterval = 0
	
	///  * The minimum time (in seconds) that the HUD is shown.
	/// * This avoids the problem of the HUD being shown and than instantly hidden.
	/// * Defaults to 0 (no minimum show time).
	var minShowTime : TimeInterval = 0
	
	/// Removes the HUD from its parent view when hidden.
	/// Defaults to NO.
	var removeFromSuperViewOnHide : Bool = true
	
	typealias MBProgressHUDCompletion = ()->Void
	
	///  Called after the HUD is hiden.
	var completion : MBProgressHUDCompletion?
	
	/// MBProgressHUD operation mode. The default is MBProgressHUDModeIndeterminate.
	var mode : MBProgressHUDSwiftMode = .text {
		didSet {
			updateIndicators()
		}
	}
	
	///  * A color that gets forwarded to all labels and supported indicators. Also sets the tintColor
	/// * for custom views on iOS 7+. Set to nil to manage color individually.
	/// * Defaults to semi-translucent black on iOS 7 and later and white on earlier iOS versions.
	var contentColor : UIColor = UIColor.white {
		didSet {
			updateViewsForColor(contentColor)
		}
	}
	
	/// The animation type that should be used when the HUD is shown and hidden.
	var animationType : MBProgressHUDSwiftAnimation = .zoom
	
	/// * The bezel offset relative to the center of the view. You can use MBProgressMaxOffset
	/// * and -MBProgressMaxOffset to move the HUD all the way to the screen edge in each direction.
	/// * E.g., CGPointMake(0.f, MBProgressMaxOffset) would position the HUD centered on the bottom edge.
	var offset : CGPoint = .zero {
		didSet {
			needsUpdateConstraints()
		}
	}
	
	/// The amount of space between the HUD edge and the HUD elements (labels, indicators or custom views).
	/// This also represents the minimum bezel distance to the edge of the HUD view.
	/// Defaults to 20.f
	var margin : CGFloat = 20 {
		didSet {
			needsUpdateConstraints()
		}
	}
	
	/// The minimum size of the HUD bezel. Defaults to CGSizeZero (no minimum size).
	var minSize : CGSize = CGSize.zero {
		didSet {
			needsUpdateConstraints()
		}
	}
	
	/// Force the HUD dimensions to be equal if possible.
	var square : Bool = false {
		didSet {
			needsUpdateConstraints()
		}
	}
	
	/// When enabled, the bezel center gets slightly affected by the device accelerometer data. Has no effect on iOS < 7.0. Defaults to YES.
	var isDefaultMotionEffectsEnabled : Bool = false {
		didSet {
			updateBezelMotionEffects()
		}
	}
	
	/// The view containing the labels and indicator (or customView).
	let bezelView : MBBackgroundViewSwift = MBBackgroundViewSwift()
	
	///  View covering the entire HUD area, placed behind bezelView.
	let backgroundView : MBBackgroundViewSwift = MBBackgroundViewSwift()
	
	/// * The UIView (e.g., a UIImageView) to be shown when the HUD is in MBProgressHUDModeCustomView.
	/// * The view should implement intrinsicContentSize for proper sizing. For best results use approximately 37 by 37 pixels.
	var customView : UIView? {
		didSet {
			if mode == .customView {
				updateIndicators()
			}
		}
	}
	
	///  * A label that holds an optional short message to be displayed below the activity indicator. The HUD is automatically resized to fit
	/// * the entire text.
	let label : UILabel = UILabel()
	
	/// A label that holds an optional details message displayed below the labelText message. The details text can span multiple lines.
	let detailsLabel : UILabel = UILabel()
	
	convenience init(_ view: UIView) {
		self.init(frame: view.bounds)
	}
	override init(frame: CGRect) {
		super.init(frame: frame)
		commonInit()
	}
	
	
	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
		commonInit()
	}
	
	/// Priviate
	fileprivate var useAnimation : Bool = true
	fileprivate var isFinished : Bool = false
	fileprivate var indicator : UIView?
	fileprivate var showStarted : Date?
	fileprivate var paddingConstraints : [NSLayoutConstraint] = [NSLayoutConstraint]()
	fileprivate var bezelConstraints : [NSLayoutConstraint] = [NSLayoutConstraint]()
	fileprivate let topSpacer : UIView = UIView()
	fileprivate let bottomSpacer : UIView = UIView()
	fileprivate var graceTimer: Timer?
	fileprivate var minShowTimer : Timer?
	fileprivate var hideDelayTimer : Timer?
	
	@objc fileprivate func handleGraceTimer() {
		
	}
	
	override func didMoveToSuperview() {
		updateForCurrentOrientationAnimated(false)
	}
	override func updateConstraints() {
		
		let metrics = ["margin":margin]
		var subviews = [topSpacer,label,detailsLabel,bottomSpacer]
		if let indicator = indicator { subviews.insert(indicator, at: 1) }
		removeConstraints(constraints)
		topSpacer.removeConstraints(topSpacer.constraints)
		bottomSpacer.removeConstraints(bottomSpacer.constraints)
		bezelView.removeConstraints(bezelConstraints)
		bezelConstraints.removeAll()
		
		var centeringConstraints = [NSLayoutConstraint]()
		centeringConstraints.append(NSLayoutConstraint(item: bezelView, attribute: .centerX, relatedBy: .equal, toItem: self, attribute: .centerX, multiplier: 1, constant: offset.x))
		centeringConstraints.append(NSLayoutConstraint(item: bezelView, attribute: .centerY, relatedBy: .equal, toItem: self, attribute: .centerY, multiplier: 1, constant: offset.y))
		applyPriority(998, to: centeringConstraints)
		addConstraints(centeringConstraints)
		
		var slideConstraint = [NSLayoutConstraint]()
		let bezels = ["bezel" : bezelView]
		slideConstraint.append(contentsOf: NSLayoutConstraint.constraints(withVisualFormat: "|-(>=margin)-[bezel]-(>=margin)-|", options: .init(rawValue: 0), metrics: metrics, views: bezels))
		slideConstraint.append(contentsOf: NSLayoutConstraint.constraints(withVisualFormat: "V:|-(>=margin)-[bezel]-(>=margin)-|", options: .init(rawValue: 0), metrics: metrics, views: bezels))
		applyPriority(998, to: slideConstraint)
		addConstraints(slideConstraint)
		
		if minSize != CGSize.zero {
			var minSizeConstraints = [NSLayoutConstraint]()
			minSizeConstraints.append(NSLayoutConstraint(item: bezelView, attribute: .width, relatedBy: .greaterThanOrEqual, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: minSize.width))
			minSizeConstraints.append(NSLayoutConstraint(item: bezelView, attribute: .height, relatedBy: .greaterThanOrEqual, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: minSize.height))
			applyPriority(997, to: minSizeConstraints)
			addConstraints(minSizeConstraints)
			bezelConstraints.append(contentsOf: minSizeConstraints)
		}
		
		if square {
			let square = NSLayoutConstraint(item: bezelView, attribute: .height, relatedBy: .equal, toItem: bezelView, attribute: .width, multiplier: 1, constant: 0)
			square.priority = 997
			addConstraint(square)
		}
		
		topSpacer.addConstraint(NSLayoutConstraint(item: topSpacer, attribute: .height, relatedBy: .greaterThanOrEqual, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: margin))
		bottomSpacer.addConstraint(NSLayoutConstraint(item: bottomSpacer, attribute: .height, relatedBy: .greaterThanOrEqual, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: margin))
		
		bezelConstraints.append(NSLayoutConstraint(item: topSpacer, attribute: .height, relatedBy: .equal, toItem: bottomSpacer, attribute: .height, multiplier: 1, constant: 0))
		var paddingConstraints = [NSLayoutConstraint]()
		var idx = 0
		for subView in subviews {
			
			bezelConstraints.append(NSLayoutConstraint(item: subView, attribute: .centerX, relatedBy: .equal, toItem: bezelView, attribute: .centerX, multiplier: 1, constant: 0))
			bezelConstraints.append(contentsOf: NSLayoutConstraint.constraints(withVisualFormat: "|-(>=margin)-[view]-(>=margin)-|", options: .init(rawValue: 0), metrics: metrics, views: ["view" : subView]))
			if idx == 0 {
				bezelConstraints.append(NSLayoutConstraint(item: subView, attribute: .top, relatedBy: .equal, toItem: bezelView, attribute: .top, multiplier: 1, constant: 0))
			} else if idx == subviews.count - 1 {
				bezelConstraints.append(NSLayoutConstraint(item: subView, attribute: .bottom, relatedBy: .equal, toItem: bezelView, attribute: .bottom, multiplier: 1, constant: 0))
			}
			if idx > 0 {
				let padding = NSLayoutConstraint(item: subView, attribute: .top, relatedBy: .equal, toItem: subviews[idx-1], attribute: .bottom, multiplier: 1, constant: 0)
				bezelConstraints.append(padding)
				paddingConstraints.append(padding)
			}
			idx = idx + 1
		}
		bezelView.addConstraints(bezelConstraints)
		updatePaddingConstraints()
		
		super.updateConstraints()
	}
	
	override func layoutSubviews() {
		if !needsUpdateConstraints() {
			updatePaddingConstraints()
		}
		super.layoutSubviews()
	}
	deinit {
		unregisterForNotifications()
	}
}

extension MBProgressHUDSwift {
	
	fileprivate func commonInit() {
		isOpaque = false
		backgroundColor = UIColor.clear
		alpha = 0.0
		autoresizingMask = [.flexibleHeight,.flexibleWidth]
		layer.allowsGroupOpacity = false
		setupViwes()
		updateIndicators()
		registerForNotifications()
	}
	
	
	fileprivate func setupViwes() {
		backgroundView.frame = bounds
		backgroundView.style = .solidColor
		backgroundView.backgroundColor = UIColor.clear
		backgroundView.autoresizingMask = [.flexibleWidth,.flexibleHeight]
		backgroundView.alpha = 0
		addSubview(backgroundView)
		
		bezelView.translatesAutoresizingMaskIntoConstraints = false
		bezelView.layer.cornerRadius = 5
		bezelView.alpha = 0
		addSubview(bezelView)
		updateBezelMotionEffects()
		
		label.adjustsFontSizeToFitWidth = false
		label.textAlignment = .center
		label.textColor = contentColor
		label.font = UIFont.boldSystemFont(ofSize: MBDefaultLabelFontSize)
		label.isOpaque = false
		label.backgroundColor = UIColor.clear
		
		
		detailsLabel.adjustsFontSizeToFitWidth = false;
		detailsLabel.textAlignment = .center;
		detailsLabel.textColor = contentColor;
		detailsLabel.numberOfLines = 0;
		detailsLabel.font = UIFont.boldSystemFont(ofSize: MBDefaultDetailsLabelFontSize)
		detailsLabel.isOpaque = false;
		detailsLabel.backgroundColor = UIColor.clear
		
		for view in [label,detailsLabel] {
			view.translatesAutoresizingMaskIntoConstraints = false
			view.setContentCompressionResistancePriority(998, for: .horizontal)
			view.setContentCompressionResistancePriority(998, for: .vertical)
			bezelView.addSubview(view)
		}
		
		topSpacer.translatesAutoresizingMaskIntoConstraints = false
		topSpacer.isHidden = true
		bezelView.addSubview(topSpacer)
		
		bottomSpacer.translatesAutoresizingMaskIntoConstraints = false
		bottomSpacer.isHidden = true
		bezelView.addSubview(bottomSpacer)
		
	}
	
	fileprivate func registerForNotifications() {
		NotificationCenter.default.addObserver(self, selector: #selector(statusBarOrientationDidChange(_:)), name: .UIApplicationDidChangeStatusBarOrientation, object: nil)
	}
	fileprivate func unregisterForNotifications() {
		NotificationCenter.default.removeObserver(self, name: .UIApplicationDidChangeStatusBarOrientation, object: nil)
	}
	
	@objc fileprivate func statusBarOrientationDidChange(_ noti: NSNotification) {
		if superview != nil {
			updateForCurrentOrientationAnimated(true)
		}
	}
	fileprivate func updateForCurrentOrientationAnimated(_ animated: Bool) {
		if let superView = superview {
			frame = superView.bounds
		}
	}
	fileprivate func updateIndicators() {
		if var _indicator = indicator {
			let isActivityIndicator = _indicator is UIActivityIndicatorView
			switch mode {
				
			case .indeterminate:
				if isActivityIndicator {
					_indicator.removeFromSuperview()
					_indicator = UIActivityIndicatorView(activityIndicatorStyle: .whiteLarge)
					
					let tmp = _indicator as! UIActivityIndicatorView
					tmp.startAnimating()
					
					bezelView.addSubview(tmp)
				}
				break
			case .customView where (customView != _indicator && customView != nil):
				_indicator.removeFromSuperview()
				_indicator = customView!
				bezelView.addSubview(_indicator)
				break
			case .text:
				_indicator.removeFromSuperview()
				indicator = nil
				break
			default:
				_indicator.removeFromSuperview()
				indicator = nil
				break
			}
			
			indicator?.translatesAutoresizingMaskIntoConstraints = false
			indicator = _indicator
			indicator?.setContentCompressionResistancePriority(998, for: .horizontal)
			indicator?.setContentCompressionResistancePriority(998, for: .vertical)
			updateViewsForColor(contentColor)
			setNeedsUpdateConstraints()
		}
	}
	
	fileprivate func updateViewsForColor(_ color: UIColor) {
		label.textColor = color
		detailsLabel.textColor = color
		
		if let view = indicator as? UIActivityIndicatorView {
			view.color = color
		}
		else {
			indicator?.tintColor = color
		}
		
	}
	
	fileprivate func updateBezelMotionEffects() {
		if bezelView.responds(to: #selector(UIView.addMotionEffect(_:))) {
			if isDefaultMotionEffectsEnabled {
				let effectOffset : Float = 10
				let effectX = UIInterpolatingMotionEffect(keyPath: "center.x", type: .tiltAlongHorizontalAxis)
				effectX.maximumRelativeValue = effectOffset
				effectX.minimumRelativeValue = -effectOffset
				
				let effectY = UIInterpolatingMotionEffect(keyPath: "center.y", type: .tiltAlongHorizontalAxis)
				effectY.maximumRelativeValue = effectOffset
				effectY.minimumRelativeValue = -effectOffset
				
				let group = UIMotionEffectGroup()
				group.motionEffects = [effectX,effectY]
				bezelView.addMotionEffect(group)
			} else {
				for effect in bezelView.motionEffects {
					bezelView.removeMotionEffect(effect)
				}
			}
		}
	}
	fileprivate func updatePaddingConstraints() {
		var hasVisibleAncestors = false
		for constraint in paddingConstraints {
			if let first = constraint.firstItem as? UIView, let second = constraint.secondItem as? UIView {
				let firstVisible = !first.isHidden && first.intrinsicContentSize != CGSize.zero
				let secondVisible = !second.isHidden && second.intrinsicContentSize != CGSize.zero
				constraint.constant = (firstVisible && (secondVisible || hasVisibleAncestors)) ? MBDefaultPadding : 0
				hasVisibleAncestors = secondVisible || hasVisibleAncestors
			}
		}
	}
}

extension MBProgressHUDSwift {
	fileprivate func applyPriority(_ priority: UILayoutPriority, to constraints: [NSLayoutConstraint]) {
		for constraint in constraints {
			constraint.priority = priority
		}
	}
}

extension MBProgressHUDSwift {
	@objc fileprivate func handleGraceTimer(_ timer: Timer){
		if isFinished {
			showUsingAnimation(useAnimation)
		}
	}
	@objc fileprivate func handleMinShowTimer(_ timer: Timer){
		hideUsingAnimation(useAnimation)
	}
	@objc fileprivate func handleHideTimer(_ timer: Timer){
		if let value = timer.userInfo as? Bool {
			hide(value)
			return
		}
		hide(false)
	}
	fileprivate func done() {
		hideDelayTimer?.invalidate()
		if isFinished {
			alpha = 0
			if removeFromSuperViewOnHide {
				removeFromSuperview()
			}
		}
		if let complete = self.completion {
			complete()
		}
	}
	
	fileprivate func showUsingAnimation(_ animated: Bool) {
		bezelView.layer.removeAllAnimations()
		backgroundView.layer.removeAllAnimations()
		hideDelayTimer?.invalidate()
		showStarted = Date()
		alpha = 1
		if animated {
			animateIn(true, type: animationType, finished: nil)
		} else {
			bezelView.alpha = 1
			backgroundView.alpha = 1
		}
	}
	fileprivate func hideUsingAnimation(_ animated: Bool) {
		if animated && showStarted != nil {
			showStarted = nil
			animateIn(false, type: animationType, finished: { [weak self] (finished) in
				self?.done()
			})
		} else {
			showStarted = nil
			bezelView.alpha = 0
			backgroundView.alpha = 1
			done()
		}
	}
	fileprivate func animateIn(_ animateIn: Bool, type: MBProgressHUDSwiftAnimation, finished: ((_ finished: Bool) -> Void)?) {
		var _type = type
		if _type == .zoom {
			_type = animateIn ? .zoomIn : .zoomOut
		}
		let small = CGAffineTransform(scaleX: 0.5, y: 0.5)
		let large = CGAffineTransform(scaleX: 1.5, y: 1.5)
		
		if animateIn && bezelView.alpha == 0 && type == .zoomIn {
			bezelView.transform = small
		} else if animateIn && bezelView.alpha == 0 && type == .zoomOut {
			bezelView.transform = large
		}
		
		let animations = {
			if animateIn {
				self.bezelView.transform = .identity
			} else if !animateIn && type == .zoomIn {
				self.bezelView.transform = large
			} else if !animateIn && type == .zoomOut {
				self.bezelView.transform = small
			}
			self.backgroundView.alpha = animateIn ? 1 : 0
			self.bezelView.alpha = animateIn ? 1 : 0
		}
		
		UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 1, options: .beginFromCurrentState, animations: animations, completion: finished)
	}
}


class MBBackgroundViewSwift: UIView {
	
	///  * The background style.
	/// * Defaults to MBProgressHUDBackgroundStyleBlur on iOS 7 or later and MBProgressHUDBackgroundStyleSolidColor otherwise.
	var style : MBProgressHUDSwiftBackgroundStyle = .solidColor {
		didSet {
			updateForBackgroundStyle()
		}
	}
	
	/// The background color or the blur tint color.
	var color : UIColor = UIColor.black {
		didSet {
			updateViewsForColor(color)
		}
	}
	
	fileprivate var effectView: UIVisualEffectView?
	
	override init(frame: CGRect) {
		super.init(frame: frame)
		style = .blur
		color = UIColor(white: 0.8, alpha: 0.6)
		clipsToBounds = true
		updateForBackgroundStyle()
		
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override var intrinsicContentSize: CGSize {
		return CGSize.zero
	}
	
	fileprivate func updateForBackgroundStyle() {
		switch style {
		case .blur:
			let effect = UIBlurEffect(style: .light)
			let _effectView = UIVisualEffectView(effect: effect)
			addSubview(_effectView)
			_effectView.frame = bounds
			_effectView.autoresizingMask = [.flexibleHeight,.flexibleWidth]
			backgroundColor = color
			layer.allowsGroupOpacity = false
			effectView = _effectView
			break
		case .solidColor:
			effectView?.removeFromSuperview()
			effectView = nil
			backgroundColor = color
			break
		}
	}
	fileprivate func updateViewsForColor(_ color: UIColor) {
		switch style {
		case .blur:
			backgroundColor = color
			break
		case .solidColor:
			backgroundColor = color
			break
		}
	}
}



























