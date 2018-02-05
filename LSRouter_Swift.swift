//
//  LSRouter_Swift.swift
//  LSRouter_Swift
//
//  Created by ArthurShuai on 2018/2/5.
//  Copyright © 2018年 ArthurShuai. All rights reserved.
//

import UIKit
import Foundation
import ObjectiveC.runtime

class LSRouter_Swift: NSObject {
    typealias LSRouterHandler = (AnyObject)->Void
    typealias LSInformationHandler = (Any)->Void

    static let LSRouter = LSRouter_Swift()

    // 重新init，防止误调取init
    private override init(){
        print("create 单例")
    }

    private var modules:Dictionary<String, Any> = [:]
    private var receiveBlks:Dictionary<String, Any> = [:]

    /// 远程App调用入口
    ///
    /// - Parameters:
    ///   - url: 格式：scheme://[target]/[actionName]?[params]
    ///          例如：aaa://targetA/actionB?id=1234&key=4567
    ///   - completion: 完成回调
    public class func performAction(url:URL, completion:LSRouterHandler?)
    {
        // 解析url中传递的参数
        var params:Dictionary<String, Any> = [:]
        for param in url.query!.components(separatedBy:"&") {
            let elts = param.components(separatedBy:"=")
            if elts.count >= 2 {
                params[elts.first!] = elts.last!
            }
        }

        // 考虑到安全性，防止黑客通过远程方式调用本地模块
        // 当前要求本地组件的actionName必须包含前缀"action_",所以远程调用的action就不能包含action_前缀
        let actionName = url.path.replacingOccurrences(of: "/", with: "")
        if actionName.hasPrefix("action_") {
            return;
        }

        // 如果需要拓展更复杂的url，可以在这个方法调用之前加入完整的路由逻辑
        LSRouter_Swift.openModule(objectClass: url.host!, actionName: "action_"+actionName, params: params, perform: completion)
    }

    /// 本地组件调用入口
    ///
    /// - Parameters:
    ///   - objectClass: 组件类名
    ///   - actionName: 待执行方法名，组件的方法名前必须添加前缀@objc
    ///   - params: 待执行方法的参数
    ///   - perform: 找到组件后下一步调用处理，如push、present组件等
    public class func openModule(objectClass:String, actionName:String?, params:Any?, perform:LSRouterHandler?)
    {
        var object:AnyObject?

        if LSRouter.modules.keys.contains(objectClass) {
            object = LSRouter.modules[objectClass] as AnyObject
        }else {
            // 获取命名空间
            var clsName:String = Bundle.main.infoDictionary!["CFBundleExecutable"] as! String
            // 若命名空间包含"-"时，系统会自动替换为"_"，故需将"-"替换为"_"才能与系统验证时一致
            clsName = clsName.replacingOccurrences(of: "-", with: "_")
            if NSClassFromString(clsName+"."+objectClass) != nil {
                let module = NSClassFromString(clsName+"."+objectClass) as! NSObject.Type
                object = module.init()
                LSRouter.modules[objectClass] = object;
            }else {
                LSRouter_Swift.showAlert(message: "Undiscovered component!")
            }
        }

        if perform != nil {
            perform!(object!)
        }

        if actionName != nil {
            let action = Selector(actionName!)

            if  object!.responds(to: action) {
                object!.perform(action, with: params)
            }else {
                LSRouter_Swift.showAlert(message: "Undiscovered action!")
                LSRouter_Swift.releaseModule(objectClass: objectClass)
            }
        }
    }

    /// 释放组件
    ///
    /// - Parameter objectClass: 组件类名
    /// - Returns: YES or NO
    public class func releaseModule(objectClass:String) -> Bool
    {
        if LSRouter.modules.keys.contains(objectClass) {
            LSRouter.modules.removeValue(forKey: objectClass)
            return true;
        }
        return false;
    }

    /// 组件发送通讯信息接口
    /// * 发送方只负责通过通讯标记发送信息
    ///
    /// - Parameters:
    ///   - information: 通讯信息
    ///   - tagName: 通讯标记，用于接收方识别接收信息
    public class func sendInformation(information:Any, tagName:String)
    {
        NotificationCenter.default.post(name: NSNotification.Name.init(tagName), object: nil, userInfo:  ["info":information])
    }

    /// 组件接收通讯信息接口
    /// * 接收方只负责通过通讯标记接收信息
    ///
    /// - Parameters:
    ///   - tagName: 通讯标记，用于接收方识别接收信息
    ///   - result: 接收到通讯信息回调，将返回通讯信息
    public class func receiveInformation(tagName:String, result:@escaping LSInformationHandler)
    {
        NotificationCenter.default.addObserver(LSRouter, selector: #selector(receivedInformation(noti:)), name: NSNotification.Name.init(tagName), object: nil)
        LSRouter.receiveBlks[tagName] = result;
    }
    @objc private func receivedInformation(noti:NSNotification)
    {
        let tagName = noti.name.rawValue
        let infotmation = noti.userInfo!["info"]

        let receiveAction:LSInformationHandler = LSRouter_Swift.LSRouter.receiveBlks[tagName] as! LSRouter_Swift.LSInformationHandler
        receiveAction(infotmation!)
    }

    private class func showAlert(message:String)
    {
        let alertVC = UIAlertController.init(title: "Warning", message: message, preferredStyle: UIAlertControllerStyle.alert)
        let action = UIAlertAction.init(title: "OK", style: UIAlertActionStyle.default, handler: nil)
        alertVC.addAction(action)
        UIApplication.shared.keyWindow?.rootViewController?.present(alertVC, animated: true, completion: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}