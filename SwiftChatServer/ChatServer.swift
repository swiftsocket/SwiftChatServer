//
//  ChatServer.swift
//  SwiftChatServer
//
//  Created by pengyunchou on 14-8-28.
//  Copyright (c) 2014年 swift. All rights reserved.
//

import Cocoa
var serverport = 9003
class ChatUser:NSObject{
    var tcpClient:TCPClient?
    var username:String=""
    var chatServer:ChatServer?
    func readMsg()->NSDictionary?{
        //read 4 byte int as type
        if let data=self.tcpClient!.read(4){
            if data.count==4{
                var ndata=NSData(bytes: data, length: data.count)
                var len:Int32=0
                ndata.getBytes(&len, length: data.count)
                if let buff=self.tcpClient!.read(Int(len)){
                    var msgd:NSData=NSData(bytes: buff, length: buff.count)
                    var msgi:NSDictionary=NSJSONSerialization.JSONObjectWithData(msgd, options: .MutableContainers, error: nil) as NSDictionary
                    return msgi
                }
            }
        }
        return nil
    }
    func messageloop(){
        while true{
            if let msg=self.readMsg(){
                self.processMsg(msg)
            }else{
                self.removeme()
                break
            }
        }
    }
    func processMsg(msg:NSDictionary){
        if msg["cmd"] as String=="nickname"{
            self.username=msg["nickname"] as String
        }
        self.chatServer!.processUserMsg(user: self, msg: msg)
    }
    func sendMsg(msg:NSDictionary){
        var jsondata=NSJSONSerialization.dataWithJSONObject(msg, options: NSJSONWritingOptions.PrettyPrinted, error: nil)
        var len:Int32=Int32(jsondata.length)
        var data:NSMutableData=NSMutableData(bytes: &len, length: 4)
        self.tcpClient!.send(data: data)
        self.tcpClient!.send(data: jsondata)
    }
    func removeme(){
        self.chatServer!.removeUser(self)
    }
    func kill(){
        self.tcpClient!.close()
    }
}
class ChatServer: NSObject {
    var clients:[ChatUser]=[]
    var server:TCPServer=TCPServer(addr: "0.0.0.0", port: serverport)
    var serverRuning:Bool=false
    @IBOutlet weak var startBtn: NSButton!
    @IBOutlet weak var stopBtn: NSButton!    
    @IBOutlet var display: NSTextView!
    func handleClient(c:TCPClient){
        self.log("new client from:"+c.addr)
        var u=ChatUser()
        u.tcpClient=c
        clients.append(u)
        u.chatServer=self
        u.messageloop()
    }
    func removeUser(u:ChatUser){
        self.log("remove user\(u.tcpClient!.addr)")
        if let possibleIndex=find(self.clients, u){
            self.clients.removeAtIndex(possibleIndex)
            self.processUserMsg(user: u, msg: ["cmd":"leave"])
        }
    }
    func processUserMsg(user u:ChatUser,msg m:NSDictionary){
        self.log("\(u.username)[\(u.tcpClient!.addr)]cmd:"+(m["cmd"] as String))
        //boardcast message
        var msgtosend=[String:String]()
        var cmd = m["cmd"] as String
        if cmd=="nickname"{
            msgtosend["cmd"]="join"
            msgtosend["nickname"]=u.username
            msgtosend["addr"]=u.tcpClient!.addr
        }else if(cmd=="msg"){
            msgtosend["cmd"]="msg"
            msgtosend["from"]=u.username
            msgtosend["content"]=(m["content"] as String)
        }else if(cmd=="leave"){
            msgtosend["cmd"]="leave"
            msgtosend["nickname"]=u.username
            msgtosend["addr"]=u.tcpClient!.addr
        }
        for user:ChatUser in self.clients{
            //if u~=user{
                user.sendMsg(msgtosend)
            //}
        }
    }
    override func awakeFromNib(){
        self.startBtn.enabled=true
        self.stopBtn.enabled=false
    }
    @IBAction func startBtnClicked(sender: AnyObject) {
        server.listen()
        self.serverRuning=true
        self.startBtn.enabled=false
        self.stopBtn.enabled=true
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), {
            while self.serverRuning{
                var client=self.server.accept()
                if let c=client{
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), {
                        self.handleClient(c)
                    })
                }
            }
        })
        self.log("server started...")
    }
    @IBAction func stopBtnClicked(sender: AnyObject) {
        self.serverRuning=false
        self.startBtn.enabled=true
        self.stopBtn.enabled=false
        self.server.close()
        //forth close all client socket
        for c:ChatUser in self.clients{
            c.kill()
        }
        self.log("server stoped...")
    }
    func log(msg:String){
        println(msg)
        dispatch_async(dispatch_get_main_queue(), {
            self.display.string=self.display.string+"\n"+msg
        })
    }
}
