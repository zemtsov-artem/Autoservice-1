//
//  RequestManager.swift
//  Autoservice
//
//  Created by артем on 28/11/2017.
//  Copyright © 2017 Kirill Ryabinin. All rights reserved.
//

import Foundation

class RequestManager {
    
    //Login state
    public enum LoginState{
        case Success
        case FailedWithError
        case FailedWithInvalideLogin
    }
    
    public enum RegisterState{
        case Success
        case AllreadyRegistred
        case FailedToRegister
    }
    
    //Server
    private static let _serverAddress:String = "http://192.168.1.70"
    private static let _serverPort:String = ":8080"
    
    //Functions names
    private static let _registerFunc:String = "/register"
    private static let _loginServ:String = "/login"
    private static let _registerServ:String = "/regserv"
    private static let _verifyServ:String = "/verifyserv"
    private static let _delServ:String = "/delserv"
    private static let _getServ:String = "/getserv"
    
    //Attributes names
    private static let _nameAttr:String = "name="
    private static let _mailAttr:String = "mail="
    private static let _phoneAttr:String = "phone="
    private static let _dateAttr:String = "date="
    private static let _timeAttr:String = "time="
    private static let _autoAttr:String = "auto="
    private static let _typeAttr:String = "type="
    private static let _stateAttr:String = "state="
    private static let _loginAttr:String = "login="
    private static let _passwordAttr:String = "password="
    
    //Symbols Helpers
    private static let _beforeAttributesSymbol:String = "?"
    private static let _concatAttributesSymbol:String = "&"
    
    //Request errors
    private static let _errorPartOfErrorMessage = "Error"
    private static let _errorPartOfReRegister = "Already registered"
    private static let _callingRequestError:String = "Error: calling request"
    private static let _invalidReceivingDataError:String = "Error: did not receive data"
    private static let _converDataToJSONError:String = "Error: trying to convert data to JSON"
    private static let _gettingMsgFromJSONError:String = "Error:Could not get message from JSON"
    private static let _accoutExistingErrorPart:String = "not exists"
    private static let _wrongPasswordError:String = "Wrong password!"
    
    //Initialize
    private init() {}
    
    //Subclasses
    public class LoginResult{
        var LoginState:LoginState
        var userId:Int
        
        public init(inputLoginState:LoginState,inputUserId:Int = Constants.INVALIDE_INT_VALUE){
            LoginState = inputLoginState
            userId = inputUserId
        }
    }
    
    public class RegisterResult{
        var RegisterState:RegisterState
        var userId:Int
        
        public init(inputRegisterState:RegisterState,inputUserId:Int = Constants.INVALIDE_INT_VALUE){
            RegisterState = inputRegisterState
            userId = inputUserId
        }
    }
    
    //Example 127.0.0.1:8080/register?login=123&password=123
    public static func registerUser(name:String,password:String,email:String,phoneNumber:String,login:String)->RegisterResult{
        //TODO ADD EMAIL AND PHONE NUMBER
    
        let requestString = _serverAddress + _serverPort +
            _registerFunc + _beforeAttributesSymbol +
            _nameAttr + name.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)! + _concatAttributesSymbol +
            _passwordAttr + password + _concatAttributesSymbol +
            _loginAttr + login + _concatAttributesSymbol +
            _phoneAttr + phoneNumber + _concatAttributesSymbol +
            _mailAttr + email
        let requestResult =  MakeRequest(requestString)
        
        guard let requestMessage = requestResult["message"] as? String else {
            print(_gettingMsgFromJSONError)
            return RegisterResult(inputRegisterState: .FailedToRegister)
        }
        if let requestError = requestResult["Error"] as? String {
            print(requestError)
            return RegisterResult(inputRegisterState: ((requestResult["Error"] as? String)?.contains(_errorPartOfReRegister))!
                ? .AllreadyRegistred
                : .FailedToRegister)
        }
        
        if let userID = requestResult["id"] as? String , let userIDValue = Int(userID) {
            return RegisterResult(inputRegisterState:.Success , inputUserId: userIDValue)
        }
        else {
            return RegisterResult(inputRegisterState: .FailedToRegister )
        }
        
    }
    
    //127.0.0.1:8080/login?login=123&password=123
    public static func loginUser(name:String,password:String)->LoginResult{
        
        let requestString = _serverAddress + _serverPort + _loginServ + _beforeAttributesSymbol +
            _loginAttr + name + _concatAttributesSymbol + _passwordAttr + password
        
        let requestResult =  MakeRequest(requestString)
        guard let requestMessage = requestResult["message"] as? String else {
            print(_gettingMsgFromJSONError)
            return LoginResult(inputLoginState: RequestManager.LoginState.FailedWithError, inputUserId: Constants.INVALIDE_INT_VALUE)
        }
        if let requestError = requestResult["Error"] as? String {
            print(requestError)
            return LoginResult(inputLoginState: RequestManager.LoginState.FailedWithError, inputUserId: Constants.INVALIDE_INT_VALUE)
        }
        if requestMessage.contains(_errorPartOfErrorMessage) ||
            requestMessage.contains(_accoutExistingErrorPart) ||
            requestMessage.contains(_wrongPasswordError){
            return LoginResult(inputLoginState: RequestManager.LoginState.FailedWithInvalideLogin, inputUserId: Constants.INVALIDE_INT_VALUE)
        }
        else{
            if let userID = requestResult["id"] as? String , let userIDValue = Int(userID) {
                return LoginResult(inputLoginState: RequestManager.LoginState.Success , inputUserId: userIDValue)
            }
            else {
                return LoginResult(inputLoginState: RequestManager.LoginState.FailedWithError , inputUserId: Constants.INVALIDE_INT_VALUE)
            }
        }
    }
    
    private static func MakeRequest(_ inputRequestString:String)->[String: Any]{
        let semaphore = DispatchSemaphore(value: 0)
        var messageResult:[String:Any] = ["Error":"Failed To Create request"]
        guard let request = CreateRequest(inputRequestString) else {
            print("Error: cannot connect to server,check is it available")
            return messageResult
        }
        InitializeConnection(urlRequest: request,completion: { answear in
            messageResult.removeValue(forKey: "Error")
            for item in answear{
                messageResult[item.key] = item.value
            }
            semaphore.signal()
        })
        semaphore.wait();
        return messageResult
    }
    
    private static func CreateRequest(_ stringForRequest:String)->URLRequest?{
        guard let url = URL(string: stringForRequest) else {
            print("Error: cannot create URL")
            return nil
        }
        return URLRequest(url: url,timeoutInterval:TimeInterval(2) )
    }
    
    private static func InitializeConnection(urlRequest:URLRequest,completion: @escaping (_ message: [String: Any]) -> ())  {
        
        let session = URLSession.shared
        
        let task = session.dataTask(with: urlRequest, completionHandler: {(data,urlResponse,error) ->Void in
            // check for any errors
            guard error == nil else {
                print(_callingRequestError)
                print(error!)
                completion(["Error":_callingRequestError])
                return
            }
            // make sure we got data
            guard let responseData = data else {
                print(_invalidReceivingDataError)
                completion(["Error":_invalidReceivingDataError])
                return
            }
            // parse the result as JSON, since that's what the API provides
            do {
                guard let todo = try JSONSerialization.jsonObject(with: responseData, options: [])
                    as? [String: Any] else {
                        print(_converDataToJSONError)
                        completion(["Error":_converDataToJSONError])
                        return
                }
                // let's just print it to prove we can access it
                print("The message is : " + todo.description)
                completion(todo)
                
            } catch  {
                print(_converDataToJSONError)
                completion(["Error":_converDataToJSONError])
                return
            }
        })
       
        task.resume()
        
    }

}

