//
//  CamViewController.swift
//  recordVideoFace
//
//  Created by QiaoWu on 2018/3/28.
//  Copyright © 2018年 EXdoll. All rights reserved.
//

import UIKit
import CoreGraphics
import AVFoundation

class CamViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, PTManagerDelegate{
    
    //usb串口数据传输类型
    enum PTType: UInt32 {
        case number = 100
        case image = 101
        case array = 102
    }
    //串口传输用 使用开源 peertalk
    let ptManager = PTManager.instance
    
    //电动机数据结构
    struct Servos {
        var name:String //电动机名称
        var currentAngle:UInt8 //当前电动机角度
        var minD:Float //视频捕捉最小输入
        var maxD:Float //视频捕捉最大输入
        var minA:Float //电动机最小输出角度
        var maxA:Float //电动机最大输出角度
    }
    //电动机用列表数据 //根据实际状况调整数值
    var data_servos = [
        Servos(name:"左侧眉毛" , currentAngle: 90, minD:0.39, maxD:0.51, minA: 20, maxA: 160), //0.6
        Servos(name:"右侧眉毛" , currentAngle: 90, minD:0.39, maxD:0.51, minA: 20, maxA: 160),
        Servos(name:"眼睛左右" , currentAngle: 90, minD:-5, maxD:5, minA: 20, maxA: 160),
        Servos(name:"眼睛上下" , currentAngle: 90, minD:-5, maxD:5, minA: 20, maxA: 160),
        Servos(name:"左上眼皮" , currentAngle: 90, minD:-5, maxD:5, minA: 10, maxA: 170),
        Servos(name:"右上眼皮" , currentAngle: 90, minD:-5, maxD:5, minA: 10, maxA: 170),
        Servos(name:"左下眼皮" , currentAngle: 90, minD:-5, maxD:5, minA: 30, maxA: 150),
        Servos(name:"右下眼皮" , currentAngle: 90, minD:-5, maxD:5, minA: 30, maxA: 150),
        Servos(name:"左唇上下" , currentAngle: 90, minD:0.7, maxD:0.9, minA: 40, maxA: 140),
        Servos(name:"右唇上下" , currentAngle: 90, minD:0.7, maxD:0.9, minA: 40, maxA: 140),
        Servos(name:"左唇前后" , currentAngle: 90, minD:0.5, maxD:1.5, minA: 30, maxA: 150),
        Servos(name:"右唇前后" , currentAngle: 90, minD:0.5, maxD:1.5, minA: 30, maxA: 150),
        Servos(name:"嘴部张合" , currentAngle: 55, minD:0.25, maxD:0.75, minA: 10, maxA: 170),//10-150
        Servos(name:"头部旋转" , currentAngle: 90, minD:-1.5, maxD:1.5, minA: 20, maxA: 160),
        Servos(name:"头部前后" , currentAngle: 90, minD:-0.35, maxD:0.35, minA: 30, maxA: 130),
        Servos(name:"头部左右" , currentAngle: 90, minD:0.7, maxD:2.3, minA: 50, maxA: 130),
        Servos(name:"左肩上下" , currentAngle: 90, minD:-5, maxD:5, minA: 40, maxA: 140),
        Servos(name:"右肩上下" , currentAngle: 90, minD:-5, maxD:5, minA: 40, maxA: 140),
        Servos(name:"左肩前后" , currentAngle: 90, minD:-5, maxD:5, minA: 40, maxA: 140),
        Servos(name:"右肩前后" , currentAngle: 90, minD:-5, maxD:5, minA: 40, maxA: 140),
        Servos(name:"呼吸频率" , currentAngle: 90, minD:-5, maxD:5, minA: 10, maxA: 170),
        Servos(name:"舌头伸缩" , currentAngle: 90, minD:-5, maxD:5, minA: 10, maxA: 170)
    ]
    
    
    //UI组件命名
    @IBOutlet weak var cameraView: UIView! //视频
    @IBOutlet weak var showText: UILabel! //显示状态
    @IBOutlet weak var screenText: UILabel! //图像文字
    @IBOutlet weak var screenImage: UIImageView! //前置图像
    
    @IBOutlet weak var defaultBtn: UIButton! //定位开始按钮
    @IBOutlet weak var recordBtn: UIButton! //记录开始按钮
    
    //加载绘图用组件 //绘制脸部捕捉线段
    var pointView:UIView = UIView()
    var drawLayers:[CAShapeLayer] = [CAShapeLayer(),CAShapeLayer()]
    //控制绘图时用属性
    var context:CGContext? = nil
    var currentLayer:Int = 0
    
    //加载视频用属性
    var device:AVCaptureDevice!
    var input:AVCaptureDeviceInput!
    var session:AVCaptureSession!
    var preview:AVCaptureVideoPreviewLayer!
    var outVide:AVCaptureVideoDataOutput!
    
    //动作标准数据采集结果
    struct FaceDef {
        var faceWidth:Float
        var faceHight:Float
        var mouthDef:Float
        var mouthOpen:Float
        var mouthClose:Float
        var eyeDef:Float
        var eyeOpen:Float
        var eyeClose:Float
        var eyeBrowDef:Float
        var cornerUDDef:Float
        var cornerFBDef:Float
        var cornerFront:Float
        var cornerBack:Float
        var pitchDef:Float
        var pitchOpen:Float
    }
    let showSamplePics = [#imageLiteral(resourceName: "表情-1"),#imageLiteral(resourceName: "表情-2"),#imageLiteral(resourceName: "表情-3"),#imageLiteral(resourceName: "表情-4"),#imageLiteral(resourceName: "表情-5"),#imageLiteral(resourceName: "表情-6"),#imageLiteral(resourceName: "表情-1")]
    //低头时角度变化常量
    var pitchByOpen:Float = 0.0
    
    //控制采集使用属性
    let DefalutTime = 0.5
    let RecordTime = 0.025
    var markManager:MGFacepp!
    var weightC:CGFloat = 1
    var hightC:CGFloat = 1
    var headRoteOrg:[Float] = [0.0,0.0,0.0] //yaw，pitch, roll //旋转，点头，歪头
    var headAngleList:[Int] = []
    var faceDefault:FaceDef = FaceDef(faceWidth: 0, faceHight: 0, mouthDef: 0, mouthOpen: 0, mouthClose: 0, eyeDef: 0, eyeOpen: 0, eyeClose: 0, eyeBrowDef: 0, cornerUDDef: 0, cornerFBDef: 0, cornerFront: 0, cornerBack: 0, pitchDef: 0, pitchOpen: 0)
    var setFaceDef:FaceDef = FaceDef(faceWidth: 0, faceHight: 0, mouthDef: 0, mouthOpen: 0, mouthClose: 0, eyeDef: 0, eyeOpen: 0, eyeClose: 0, eyeBrowDef: 0, cornerUDDef: 0, cornerFBDef: 0, cornerFront: 0, cornerBack: 0, pitchDef: 0, pitchOpen: 0)
    
    var tempFaceRecod:[[Float]] = [[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[]]
    let testProText:[String] = ["对准头部微张嘴","张大嘴","闭紧嘴","闭左眼争大右眼","咧嘴","撅嘴","完成"]
    var mouthOnOpen:UInt8 = 0
    var isPlay:Bool = false
    var isTest:Bool = false
    var isReadyNextStep:Bool = false
    var isRecord:Bool = false
    var isActive:Bool = true
    var isGetSize:Bool = false
    var tempPoints:[CGPoint] = []
    var defaultProcess:Int = 0
    var subDefaultProcess:Int = 0
   
    //串口传输数据
    var sendingData:[UInt8] = []
    //时间
    var recordTimer:Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        screenImage.image = nil
        recordBtn.isEnabled = false
        defaultBtn.isEnabled = false
        defaultBtn.setTitle("等待", for: .normal)
        
        //初始化
        setupVideo()
        setupSrial()
    }
    // MARK: - init function
    //传输串口初始化
    func setupSrial() -> Void {
        ptManager.delegate = self
        ptManager.connect(portNumber: 2345)
    }
    //初始化加载摄像头
    func setupVideo() -> Void {
        cameraView.frame = UIScreen.main.bounds
        //前置摄像头初始化
        self.device = AVCaptureDevice.default(AVCaptureDevice.DeviceType.builtInWideAngleCamera, for: AVMediaType.video, position: .front)
        if((self.device) != nil){
            self.session = AVCaptureSession()
            do{
                self.input = try AVCaptureDeviceInput(device: self.device)
            }catch{
                return
            }
            //session设定
            session.beginConfiguration()
            //不一定需要 -如果不要，就需要主线程？
            if(session.canSetSessionPreset(.hd1280x720)){
                session.canSetSessionPreset(.hd1280x720)
            }else{
                print("无法设置尺寸")
            }
            self.outVide = AVCaptureVideoDataOutput()
            if(session.canAddInput(input)){
                session.addInput(input)
            }else{
                return
            }
            if(session.canAddOutput(outVide)){
                self.outVide.alwaysDiscardsLateVideoFrames = true
                self.outVide.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String : Int(kCVPixelFormatType_32BGRA)]
                //self.outVide.videoSettings = [kCVPixelBufferPixelFormatTypeKey:NSNumber(value: kCVPixelFormatType_32BGRA),kCVPixelBufferWidthKey:NSNumber(value: 1280),kCVPixelBufferHeightKey:NSNumber(value: 720)] as [String : Any]
                self.outVide.connection(with: .video)?.videoOrientation = AVCaptureVideoOrientation.portrait
                session.addOutput(outVide)
                //线程还没弄清楚怎样效率更好
                //let subQueue:dispatch_queue_t = dispatch_queue_create("subQueue", nil)
                //let quet = DispatchQueue(label: "exdoll.video", qos: .userInteractive, attributes: .concurrent, autoreleaseFrequency: .inherit, target: DispatchQueue.main)
                outVide.setSampleBufferDelegate(self, queue: DispatchQueue.main)
            }else{
                return
            }

            //显示层
            preview = AVCaptureVideoPreviewLayer(session: self.session)
            preview.frame = UIScreen.main.bounds //cameraView.bounds
            preview.videoGravity = AVLayerVideoGravity.resizeAspectFill
            cameraView.layer.addSublayer(preview)
            //提交设置？
            self.session.commitConfiguration()
            
            //加载绘制涂层
            pointView.frame = cameraView.bounds
            pointView.alpha = 1
            cameraView.addSubview(pointView)
            pointView.layer.addSublayer(drawLayers[currentLayer])
        
            //启动face++SDK
            checkFacePlusLicence()
        }else{
            self.screenText.text = "摄像头错误"
            print("摄像头错误")
        }
    }
    // MARK: - defaultBtn
    //启动视频录制 按钮
    @IBAction func clickDefaultCheckBtanAction(_ sender: UIButton) {
        //第一次按
        if(!isPlay){
            self.screenImage.image = self.showSamplePics[0]
            self.isRecord = false
            self.isReadyNextStep = false
            self.defaultProcess = 0
            self.session.startRunning()
            self.isPlay = true
            //计时器启动
            self.recordTimer = Timer.scheduledTimer(timeInterval: self.DefalutTime, target: self, selector: #selector(CamViewController.checkDefaultOnTime), userInfo: nil, repeats: true)
            self.isTest = true
            sender.isEnabled = false
            sender.setTitle("检测中", for: .normal)
        }else{
            //进行下一步测量
            if(isTest){
                isReadyNextStep = false
                sender.isEnabled = false
                sender.setTitle("下一步", for: .normal)
                if(defaultProcess>=5){
                    sender.setTitle("完成", for: .normal)
                }
                self.recordTimer?.fireDate = Date.distantPast
                self.showText.text = testProText[defaultProcess]
            }
        }
        
    }
    // MARK: - checkDefaultData
    //视频数据定位流程
    @objc func checkDefaultOnTime() -> Void {
        //记录数据
        findAllDistence(points: tempPoints)
        //记录程序未完成一次流程时
        if(subDefaultProcess<=5){
            //多次记录检测数据
            if(checkDefaultProcessing()){
                self.screenImage.alpha = 0.2
                self.screenText.backgroundColor = UIColor.white
                subDefaultProcess += 1
            }else{
                self.screenText.text = "测量位置不准确"
                self.screenImage.alpha = 0.8
                self.screenText.backgroundColor = nil
            }
        }else{
            //完成一次检测
            defaultProcess += 1
            self.screenImage.image = self.showSamplePics[defaultProcess]
            self.screenImage.alpha = 0.8
            subDefaultProcess = 0
            self.screenText.text = "下一步:\(testProText[defaultProcess])"
            self.screenText.backgroundColor = nil
            self.defaultBtn.setTitle("下一步", for: .normal)
            //暂停时间计数
            self.recordTimer?.fireDate = Date.distantFuture
            self.defaultBtn.isEnabled = true
            if(defaultProcess>=6){
                self.recordTimer?.invalidate()
                self.screenText.text = "完成检测"
                self.screenText.backgroundColor = UIColor.white
                self.defaultBtn.setTitle("完成", for: .normal)
                self.defaultBtn.isEnabled = false
                self.isTest = false
                self.screenImage.alpha = 0
                self.screenImage.image = nil
                self.recordBtn.isEnabled = true
                //测量完成 数据校准
                self.orgAllAngles()
                self.setServoDatas()
                return
            }
        }
    }
    
    //检测记录数据
    func checkDefaultProcessing() -> Bool {
        var resoult = false
        if(checkFaceOnArea()){
            resoult = true
            switch defaultProcess {
            case 0:
                //记录头部标准动作数值
                tempFaceRecod[0].append(faceDefault.faceWidth) //脸宽 0
                tempFaceRecod[1].append(faceDefault.faceHight) //脸长 0
                tempFaceRecod[2].append(faceDefault.mouthDef) //嘴部
                tempFaceRecod[3].append(faceDefault.eyeDef) //眼部
                tempFaceRecod[4].append(faceDefault.eyeBrowDef) //眉毛
                tempFaceRecod[5].append(faceDefault.cornerUDDef) //嘴角上下
                tempFaceRecod[6].append(faceDefault.cornerFBDef) //嘴角前后
                tempFaceRecod[7].append(headRoteOrg[1]) //点头
                tempFaceRecod[15].append(headRoteOrg[0]) //转头
                tempFaceRecod[16].append(headRoteOrg[2]) //歪头
                self.screenText.text = "对准头部微张嘴 \(5 - self.subDefaultProcess)"
                break
            case 1:
                //记录张大嘴的数据
                if(tempFaceRecod[8].count>1){
                    let temp = fabs(faceDefault.mouthDef-tempFaceRecod[8][0])
                    if(temp>0.5){
                        resoult = false
                        break
                    }else{
                        tempFaceRecod[8].append(faceDefault.mouthDef) //张大嘴
                        tempFaceRecod[9].append(headRoteOrg[1])  //张大嘴时头部
                        self.screenText.text = "张大嘴 \(5 - self.subDefaultProcess)"
                    }
                }else{
                    tempFaceRecod[8].append(faceDefault.mouthDef)
                    tempFaceRecod[9].append(headRoteOrg[1])
                    self.screenText.text = "张大嘴 \(5 - self.subDefaultProcess)"
                }
                break
            case 2:
                //记录闭紧嘴的数据
                if(tempFaceRecod[10].count>1){
                    let temp = fabs(faceDefault.mouthDef-tempFaceRecod[10][0])
                    if(temp>0.5){
                        resoult = false
                        break
                    }else{
                        tempFaceRecod[10].append(faceDefault.mouthDef) //闭紧嘴
                        self.screenText.text = "闭紧嘴 \(5 - self.subDefaultProcess)"
                    }
                }else{
                    tempFaceRecod[10].append(faceDefault.mouthDef)
                    self.screenText.text = "闭紧嘴 \(5 - self.subDefaultProcess)"
                }
                break
            case 3:
                //记录闭左眼睁右眼的数据
                if(tempFaceRecod[11].count>1){
                    let temp1 = fabs(faceDefault.eyeClose-tempFaceRecod[11][0])
                    let temp2 = fabs(faceDefault.eyeOpen-tempFaceRecod[12][0])
                    if(temp1>0.5 && temp2>0.5){
                        resoult = false
                        break
                    }else{
                        tempFaceRecod[11].append(faceDefault.eyeClose) //闭左眼
                        tempFaceRecod[12].append(faceDefault.eyeOpen) //闭左眼
                        self.screenText.text = "闭左眼争右眼 \(5 - self.subDefaultProcess)"
                    }
                }else{
                    tempFaceRecod[11].append(faceDefault.eyeClose) //闭左眼
                    tempFaceRecod[12].append(faceDefault.eyeOpen) //闭左眼
                    self.screenText.text = "闭左眼争右眼 \(5 - self.subDefaultProcess)"
                }
                break
            case 4:
                //记录咧嘴数据
                if(tempFaceRecod[13].count>1){
                    let temp = fabs(faceDefault.cornerFBDef-tempFaceRecod[13][0])
                    if(temp>0.5){
                        resoult = false
                        break
                    }else{
                        tempFaceRecod[13].append(faceDefault.cornerFBDef) //咧嘴
                        tempFaceRecod[17].append(faceDefault.cornerUDDef) //嘴角上下
                        self.screenText.text = "咧嘴 \(5 - self.subDefaultProcess)"
                    }
                }else{
                    tempFaceRecod[13].append(faceDefault.cornerFBDef) //咧嘴
                    tempFaceRecod[17].append(faceDefault.cornerUDDef) //嘴角上下
                    self.screenText.text = "咧嘴 \(5 - self.subDefaultProcess)"
                }
                break
            case 5:
                //记录撅嘴数据
                if(tempFaceRecod[14].count>1){
                    let temp = fabs(faceDefault.cornerFBDef-tempFaceRecod[14][0])
                    if(temp>0.5){
                        resoult = false
                        break
                    }else{
                        tempFaceRecod[14].append(faceDefault.cornerFBDef) //撅嘴
                        self.screenText.text = "撅嘴 \(5 - self.subDefaultProcess)"
                    }
                }else{
                    tempFaceRecod[14].append(faceDefault.cornerFBDef) //撅嘴
                    self.screenText.text = "撅嘴 \(5 - self.subDefaultProcess)"
                }
                break
            case 6:
                //记录完成
                resoult = true
            default:
                resoult = false
                break
            }
        }else{
            resoult = false
        }
        return resoult
    }
    
    //赋值脸部测定标准数值
    func orgAllAngles() -> Void {
        self.isTest = false
        defaultProcess = 7
        //取得采集数据的平均值
        setFaceDef.faceWidth = getAvgNumber(array: tempFaceRecod[0])
        setFaceDef.faceHight = getAvgNumber(array: tempFaceRecod[1])
        setFaceDef.mouthDef = getAvgNumber(array: tempFaceRecod[2])
        setFaceDef.eyeDef = getAvgNumber(array: tempFaceRecod[3])
        setFaceDef.eyeBrowDef = getAvgNumber(array: tempFaceRecod[4])
        setFaceDef.cornerUDDef = getAvgNumber(array: tempFaceRecod[5])
        setFaceDef.cornerFBDef = getAvgNumber(array: tempFaceRecod[6])
        setFaceDef.pitchDef = getAvgNumber(array: tempFaceRecod[7])
        setFaceDef.mouthOpen = getAvgNumber(array: tempFaceRecod[8])
        setFaceDef.pitchOpen = getAvgNumber(array: tempFaceRecod[9]) - getAvgNumber(array: tempFaceRecod[7])
        setFaceDef.mouthClose = getAvgNumber(array: tempFaceRecod[10])
        setFaceDef.eyeClose = getAvgNumber(array: tempFaceRecod[11])
        setFaceDef.eyeOpen = getAvgNumber(array: tempFaceRecod[12])
        setFaceDef.cornerBack = getAvgNumber(array: tempFaceRecod[13])
        setFaceDef.cornerFront = getAvgNumber(array: tempFaceRecod[14])
    }
    //定义脸部数据
    func setServoDatas() -> Void {
        //头部
        data_servos[13].minD = getAvgNumber(array: tempFaceRecod[15]) - 1.5
        data_servos[13].maxD = getAvgNumber(array: tempFaceRecod[15]) + 1.5
        data_servos[14].minD = setFaceDef.pitchDef - 0.35
        data_servos[14].maxD = setFaceDef.pitchDef + 0.35
        data_servos[15].minD = getAvgNumber(array: tempFaceRecod[16]) - 0.8
        data_servos[15].maxD = getAvgNumber(array: tempFaceRecod[16]) + 0.8
        //眉毛
        data_servos[0].minD = setFaceDef.eyeBrowDef - 0.3 //0.6
        data_servos[0].maxD = setFaceDef.eyeBrowDef + 0.3
        data_servos[1].minD = setFaceDef.eyeBrowDef - 0.3
        data_servos[1].maxD = setFaceDef.eyeBrowDef + 0.3
        //上眼皮
        let eyeD = fabs(setFaceDef.eyeOpen - setFaceDef.eyeClose)/1.6 //2
        data_servos[4].minD = setFaceDef.eyeDef - eyeD
        data_servos[4].maxD = setFaceDef.eyeDef + eyeD
        data_servos[5].minD = setFaceDef.eyeDef - eyeD
        data_servos[5].maxD = setFaceDef.eyeDef + eyeD
        //嘴角前后
        let conrF = fabs(setFaceDef.cornerFront - setFaceDef.cornerBack)/2
        data_servos[10].minD = setFaceDef.cornerFBDef - conrF
        data_servos[10].maxD = setFaceDef.cornerFBDef + conrF
        data_servos[11].minD = setFaceDef.cornerFBDef - conrF
        data_servos[11].maxD = setFaceDef.cornerFBDef + conrF
        //嘴角上下
        let conrU = fabs(setFaceDef.cornerUDDef - getAvgNumber(array: tempFaceRecod[17]))/2 //嘴角上下
        data_servos[8].minD = setFaceDef.cornerUDDef - conrU
        data_servos[8].maxD = setFaceDef.cornerUDDef + conrU
        data_servos[9].minD = setFaceDef.cornerUDDef - conrU
        data_servos[9].maxD = setFaceDef.cornerUDDef + conrU
        //嘴部张合
        let mouthO = fabs(setFaceDef.mouthOpen - setFaceDef.mouthClose)/1.7
        data_servos[12].minD = setFaceDef.mouthDef - mouthO
        data_servos[12].maxD = setFaceDef.mouthDef + mouthO
        self.mouthOnOpen = UInt8((self.data_servos[12].maxA - self.data_servos[12].minA)/2)
        //点头减量
        let ano = checkAngleSafeOut(putin:getAvgNumber(array: tempFaceRecod[9]), nu: 14)
        let anr = checkAngleSafeOut(putin:getAvgNumber(array: tempFaceRecod[7]), nu: 14)
        //嘴部抬头差值
        pitchByOpen = Float(abs(Int(ano)-Int(anr)))
    }
    // MARK: - recordBtn
    //点击开始录制按钮
    @IBAction func startRecodeDatas(_ sender: UIButton) {
        if(isRecord){
            sender.setTitle("录制", for: .normal)
            isActive = false
        }else{
            sender.setTitle("停止", for: .normal)
            isActive = true
            //从新启动定时器
            self.screenText.backgroundColor = nil
            self.screenText.text = ""
            self.recordTimer = Timer.scheduledTimer(timeInterval: self.RecordTime, target: self, selector: #selector(CamViewController.sendingDatasTo), userInfo: nil, repeats: true)
        }
        isRecord = !isRecord
    }
    
    // MARK: - video
    //视频显示和采集
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        //采集视频
        if(isGetSize){
            let quet = DispatchQueue(label: "exdoll.testCarmera.check", qos: .userInteractive)
            quet.sync {
                var tembf:CMSampleBuffer? = nil
                CMSampleBufferCreateCopy(kCFAllocatorDefault, sampleBuffer, &tembf)
                DispatchQueue.main.async {
                    self.getPoints(sbuffer: tembf!)
                }
            }
        }else{
            //第一次采集时确定视频尺寸
            self.getVidePicSize(sampleBuffer: sampleBuffer)
            isGetSize = true
        }
    }
    
    //取得视频尺寸
    func getVidePicSize(sampleBuffer: CMSampleBuffer) -> Void {
        let imageBuffer:CVImageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
        CVPixelBufferLockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
        let width:size_t  = CVPixelBufferGetWidth(imageBuffer)
        let height:size_t = CVPixelBufferGetHeight(imageBuffer)
        print("图片尺寸是：\(width)+\(height)")
        self.weightC = pointView.bounds.size.width / CGFloat(height)
        self.hightC = pointView.bounds.size.height / CGFloat(width)
        CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
    }
    
    // MARK: - Face++
    //Face++检查授权
    func checkFacePlusLicence() -> Void {
        let needLicence = MGFaceLicenseHandle.getNeedNetLicense()
        if(needLicence){
            MGFaceLicenseHandle.license(forNetwokrFinish: { (License, sdkData) in
                if(!License){
                    print("license failed !!!")
                    self.showText.text = "SDK错误"
                }else{
                    print("license success !!!")
                    self.initFacePlus()
                    //定位采集准备初始化
                    DispatchQueue.main.async {
                        self.screenImage.image = self.showSamplePics[0]
                        self.screenImage.alpha = 0.7
                        self.screenText.text = "对准镜头嘴部微张"
                        self.showText.text = "准备开始检查定位"
                        self.defaultBtn.isEnabled = true
                        self.defaultBtn.setTitle("开始", for: .normal)
                        self.defaultProcess = 0
                        self.subDefaultProcess = 0
                    }
                }
            })
        }else{
            print("SDK is offline version!")
        }
    }
    //Face++开始初始化
    func initFacePlus() -> Void{
        //初始化检测器
        let modelPath = Bundle.main.path(forResource: KMGFACEMODELNAME, ofType: "")
        let modelData = NSData(contentsOfFile: modelPath!)
        markManager = MGFacepp(model: modelData! as Data?) { (config:MGFaceppConfig!) in
            //config!.orientation =  0
            config!.orientation = 90
            config!.pixelFormatType = MGPixelFormatType(rawValue: Int(kCVPixelFormatType_32BGRA))!
        }
        DispatchQueue.main.async {
            self.showText.text = "准备开始测量定位"
        }
        print("------ 授权没问题 ---------")
    }
    
    // MARK: - get pints every frame
    //Face++获取关键点
    func getPoints(sbuffer:CMSampleBuffer) -> Void {
        markManager.beginDetectionFrame()
        let imageData = MGImageData(sampleBuffer: sbuffer)
        if((imageData) != nil){
            let pointArray = markManager.detect(with: imageData)!
            for info:MGFaceInfo in pointArray {
                markManager.getGetLandmark(info, isSmooth: true, pointsNumber:81)
                //markManager.get
                //数据赋值
                self.getHeadRoteAngles(info: info)
                if(isRecord){
                    //采集用数据
                    self.sendingData = self.getAllAngles(points: info.points as! [CGPoint])
                }else{
                    //测量用数据
                    self.tempPoints = info.points as! [CGPoint]
                }
                //绘图
                let chl = self.drawFace(points: info.points)
                self.pointView.layer.replaceSublayer(self.drawLayers[self.currentLayer], with: self.drawLayers[chl])
                self.currentLayer = chl
            }
        }else{
            self.screenText.text = "图片数据错误"
        }
        markManager.endDetectionFrame()
    }
    
    // MARK: - draw lins on screen
    //绘制关键点
    func drawFace(points:Array<Any>) -> Int {
        var dlayer = 0
        if (currentLayer == 0){
            dlayer = 1
        }
        let lay = self.drawLayers[dlayer]
        lay.strokeColor = UIColor.green.cgColor
        lay.fillColor = UIColor(hue: 0, saturation: 0, brightness: 0, alpha: 0.1).cgColor
        lay.lineWidth = 2
        let path = CGMutablePath()
        //根据捕捉点画嘴
        path.move(to: cgpingIt(points: points, index: 44))
        path.addLine(to: cgpingIt(points: points, index: 48))
        path.addLine(to: cgpingIt(points: points, index: 46))
        path.addLine(to: cgpingIt(points: points, index: 49))
        path.addLine(to: cgpingIt(points: points, index: 45))
        path.addLine(to: cgpingIt(points: points, index: 60))
        path.addLine(to: cgpingIt(points: points, index: 55))
        path.addLine(to: cgpingIt(points: points, index: 59))
        path.addLine(to: cgpingIt(points: points, index: 44))
        //根据捕捉点画眼
        path.move(to: cgpingIt(points: points, index: 1))
        path.addLine(to: cgpingIt(points: points, index: 3))
        path.addLine(to: cgpingIt(points: points, index: 2))
        path.addLine(to: cgpingIt(points: points, index: 8))
        path.addLine(to: cgpingIt(points: points, index: 6))
        path.addLine(to: cgpingIt(points: points, index: 1))
        path.move(to: cgpingIt(points: points, index: 10))
        path.addLine(to: cgpingIt(points: points, index: 12))
        path.addLine(to: cgpingIt(points: points, index: 11))
        path.addLine(to: cgpingIt(points: points, index: 17))
        path.addLine(to: cgpingIt(points: points, index: 15))
        path.addLine(to: cgpingIt(points: points, index: 10))
        //根据捕捉点画鼻子
        path.move(to: cgpingIt(points: points, index: 38))
        path.addLine(to: cgpingIt(points: points, index: 40))
        path.addLine(to: cgpingIt(points: points, index: 35))
        path.addLine(to: cgpingIt(points: points, index: 41))
        path.addLine(to: cgpingIt(points: points, index: 39))
        //根据捕捉点画脸
        path.move(to: cgpingIt(points: points, index: 66))
        path.addLine(to: cgpingIt(points: points, index: 67))
        path.addLine(to: cgpingIt(points: points, index: 68))
        path.addLine(to: cgpingIt(points: points, index: 69))
        path.addLine(to: cgpingIt(points: points, index: 71))
        path.move(to: cgpingIt(points: points, index: 74))
        path.addLine(to: cgpingIt(points: points, index: 75))
        path.addLine(to: cgpingIt(points: points, index: 76))
        path.addLine(to: cgpingIt(points: points, index: 77))
        path.addLine(to: cgpingIt(points: points, index: 79))
        //根据捕捉点画眉毛
        path.move(to: cgpingIt(points: points, index: 18))
        path.addLine(to: cgpingIt(points: points, index: 22))
        path.addLine(to: cgpingIt(points: points, index: 24))
        path.addLine(to: cgpingIt(points: points, index: 19))
        path.move(to: cgpingIt(points: points, index: 27))
        path.addLine(to: cgpingIt(points: points, index: 32))
        path.addLine(to: cgpingIt(points: points, index: 30))
        path.addLine(to: cgpingIt(points: points, index: 26))
        lay.path = path
        lay.frame = pointView.bounds
        return dlayer
        
    }
    //当前点CGpoint 位置比例变换
    func cgpingIt(points:Array<Any>,index:Int) -> CGPoint {
        var p:CGPoint =  CGPoint()
        let o = points[index] as! CGPoint
        //调整比例
        p.x = o.y * self.weightC
        p.y = o.x * self.hightC
        return p
    }
    
    // MARK: - check points data
    //测量脸部各个点距离
    func findAllDistence(points:Array<Any>) -> Void {
        faceDefault.faceWidth = (distendsOf2Point(points: points, rp1: 68, rp2: 35)+distendsOf2Point(points: points, rp1: 76, rp2: 35))/2
        faceDefault.faceHight = (distendsOf2Point(points: points, rp1: 36, rp2: 35)+distendsOf2Point(points: points, rp1: 37, rp2: 35))/2
        faceDefault.mouthDef = distendsOf2Point(points: points, rp1: 46, rp2: 55)/faceDefault.faceHight
        faceDefault.eyeDef = (distendsOf2Point(points: points, rp1: 3, rp2: 4)+distendsOf2Point(points: points, rp1: 12, rp2: 13))*0.5/faceDefault.faceHight
        faceDefault.eyeOpen = (distendsOf2Point(points: points, rp1: 3, rp2: 4))/faceDefault.faceHight
        faceDefault.eyeClose = (distendsOf2Point(points: points, rp1: 12, rp2: 13))/faceDefault.faceHight
        faceDefault.eyeBrowDef = (distendsOf2Point(points: points, rp1: 20, rp2: 40)+distendsOf2Point(points: points, rp1: 28, rp2: 41))*0.5/faceDefault.faceHight
        faceDefault.cornerUDDef = (distendsOf2Point(points: points, rp1: 44, rp2: 40)+distendsOf2Point(points: points, rp1: 45, rp2: 41))*0.5/faceDefault.faceHight
        faceDefault.cornerFBDef = (distendsOf2Point(points: points, rp1: 44, rp2: 47)+distendsOf2Point(points: points, rp1: 45, rp2: 47))*0.5/faceDefault.faceWidth
        //print("检测尺寸嘴部张和大小：\(Int(faceDefault.mouthDef))|脸宽：\(Int(faceDefault.faceWidth))|脸长：\(Int(faceDefault.faceHight))")
    }
    //2点间路径距离
    func distendsOf2Point(points:Array<Any>, rp1:Int,rp2:Int) -> Float {
        let p1 = cgpingIt(points: points, index: rp1)
        let p2 = cgpingIt(points: points, index: rp2)
        let deltaX = p2.x - p1.x;
        let deltaY = p2.y - p1.y;
        return Float(sqrt(deltaX*deltaX + deltaY*deltaY ));
    }
    //Face++获得头部动作位置
    public func getHeadRoteAngles(info:MGFaceInfo) -> Void {
        if(isTest || isRecord){
            self.headRoteOrg[0] = info.yaw
            self.headRoteOrg[1] = info.pitch
            self.headRoteOrg[2] = info.roll
        }
        //print("头部动作:旋转yaw\(headRoteOrg[0]),点头pitch\(headRoteOrg[1]),歪头roll\(headRoteOrg[2])")
    }
    //确定脸部是否正确位置
    func checkFaceOnArea() -> Bool {
        if(faceDefault.faceWidth<100 && faceDefault.faceWidth>60 && faceDefault.faceHight>40 && faceDefault.faceHight<70 ){
            return true
        }else{
            return false
        }
    }
    // MARK: - sending face data
    //计算发送角度
    func getAllAngles(points:Array<Any>) -> [UInt8] {
        var data:[UInt8] = []
        //let faceWidth = (distendsOf2Point(points: points, rp1: 68, rp2: 35)+distendsOf2Point(points: points, rp1: 76, rp2: 35))/2
        let faceHight = (distendsOf2Point(points: points, rp1: 36, rp2: 35)+distendsOf2Point(points: points, rp1: 37, rp2: 35))/2
        //0 Servos(name:"左侧眉毛" , currentAngle: 90, minD:0.39, maxD:0.51, minA: 40, maxA: 140), //0.6
        data.append(checkAngleSafeOut(putin: distendsOf2Point(points: points, rp1: 20, rp2: 40)/faceHight, nu: 0))
        //1 Servos(name:"左侧眉毛" , currentAngle: 90, minD:0.39, maxD:0.51, minA: 40, maxA: 140), //0.6
        data.append(checkAngleSafeOut(putin: distendsOf2Point(points: points, rp1: 28, rp2: 41)/faceHight, nu: 1))
        //2 Servos(name:"眼睛左右" , currentAngle: 90, minD:-5, maxD:5, minA: 20, maxA: 160),
        data.append(90)
        //3 Servos(name:"眼睛上下" , currentAngle: 90, minD:-5, maxD:5, minA: 20, maxA: 160),
        data.append(90)
        //4 Servos(name:"左上眼皮" , currentAngle: 90, minD:-5, maxD:5, minA: 30, maxA: 160),
        data.append(checkAngleSafeOut(putin: distendsOf2Point(points: points, rp1: 3, rp2: 4)/faceHight, nu: 4))
        //5 Servos(name:"右上眼皮" , currentAngle: 90, minD:-5, maxD:5, minA: 30, maxA: 160),
        data.append(checkAngleSafeOut(putin: distendsOf2Point(points: points, rp1: 12, rp2: 13)/faceHight, nu: 5))
        //6 Servos(name:"左下眼皮" , currentAngle: 90, minD:-5, maxD:5, minA: 40, maxA: 140),
        let ed01 = Int((90-Int(data[4]))/3)
        data.append(UInt8(90+ed01))
        //7 Servos(name:"右下眼皮" , currentAngle: 90, minD:-5, maxD:5, minA: 40, maxA: 140),
        let ed02 = Int((90-Int(data[5]))/3)
        data.append(UInt8(90+ed02))
        //8 Servos(name:"左唇上下" , currentAngle: 90, minD:0.7, maxD:0.9, minA: 40, maxA: 140),
        data.append(checkAngleSafeOut(putin: distendsOf2Point(points: points, rp1: 44, rp2: 40)/faceHight, nu: 8))
        //9 Servos(name:"右唇上下" , currentAngle: 90, minD:0.7, maxD:0.9, minA: 40, maxA: 140),
        data.append(checkAngleSafeOut(putin: distendsOf2Point(points: points, rp1: 45, rp2: 41)/faceHight, nu: 9))
        //10 Servos(name:"左唇前后" , currentAngle: 90, minD:0.5, maxD:1.5, minA: 20, maxA: 160),
        data.append(checkAngleSafeOut(putin: distendsOf2Point(points: points, rp1: 44, rp2: 47)/distendsOf2Point(points: points, rp1: 68, rp2: 35), nu: 10))
        //11 Servos(name:"右唇前后" , currentAngle: 90, minD:0.5, maxD:1.5, minA: 20, maxA: 160),
        data.append(checkAngleSafeOut(putin: distendsOf2Point(points: points, rp1: 47, rp2: 45)/distendsOf2Point(points: points, rp1: 35, rp2: 76), nu: 11))
        //12 Servos(name:"嘴部张合" , currentAngle: 55, minD:0.25, maxD:0.75, minA: 0, maxA: 110),//10-150
        let mothopentemp =  distendsOf2Point(points: points, rp1: 46, rp2: 55)/faceHight
        data.append(checkAngleSafeOut(putin:mothopentemp, nu: 12))
        //13 Servos(name:"头部旋转" , currentAngle: 90, minD:-1.5, maxD:1.5, minA: 30, maxA: 150),
        data.append(checkAngleSafeOut(putin:self.headRoteOrg[0], nu: 13))
        //14 Servos(name:"头部前后" , currentAngle: 90, minD:-0.35, maxD:0.35, minA: 60, maxA: 110),
        //data.append(checkAngleSafeOut(putin:(self.headRoteOrg[1]-(mothopentemp*pitchByOpen)), nu: 14))
        data.append(checkAngleSafeOut(putin:self.headRoteOrg[1], nu: 14))
        //let temMoopn = checkAngleSafeOut(putin:setFaceDef.pitchOpen, nu: 14)
        //print("嘴部差值：\(temMoopn)")
        //let headFB:Int = (Int(data[12])-Int(self.mouthOnOpen))/2
        //let headCR:Int = Int(checkAngleSafeOut(putin:(self.headRoteOrg[1]), nu: 14))
        //data.append(UInt8(headCR+headFB))
        
        //数据校准 //需要从新计算规划
        if(data[12]>self.mouthOnOpen){
            let ord = Int(fgmap(x: Float(data[12]), in_min:Float(data_servos[12].minA), in_max: Float(data_servos[12].maxA), out_min: 0, out_max:pitchByOpen)) //Float(temMoopn), 20 , Float(self.mouthOnOpen)
            let tem = Int(data[14])
            data[14] = UInt8(tem+ord)
        }
        if(data[14])<95{
            let mo = (95-Int(data[14]))*2
            data[0] = sfun_rotoeCutWhenHeadMove(rot: sfun_cutRoteHead(org: Int(data[0])-mo, index: 0))
            data[1] = sfun_rotoeCutWhenHeadMove(rot: sfun_cutRoteHead(org: Int(data[1])-mo, index: 1))
            data[4] = sfun_rotoeCutWhenHeadMove(rot: sfun_cutRoteHead(org: Int(data[4])-mo, index: 4))
            data[5] = sfun_rotoeCutWhenHeadMove(rot: sfun_cutRoteHead(org: Int(data[5])-mo, index: 5))
            data[8] = sfun_rotoeCutWhenHeadMove(rot: sfun_cutRoteHead(org: Int(data[8])-mo, index: 8))
            data[9] = sfun_rotoeCutWhenHeadMove(rot: sfun_cutRoteHead(org: Int(data[9])-mo, index: 9))
            //print("抬低头减值：\(mo) | 抬头：\(data[14])")
        }
        if(data[14]>100){
            data[0] = sfun_rotoeCutWhenHeadMove(rot: Int(data[0]))
            data[1] = sfun_rotoeCutWhenHeadMove(rot: Int(data[1]))
            data[4] = sfun_rotoeCutWhenHeadMove(rot: Int(data[4]))
            data[5] = sfun_rotoeCutWhenHeadMove(rot: Int(data[5]))
            data[8] = sfun_rotoeCutWhenHeadMove(rot: Int(data[8]))
            data[9] = sfun_rotoeCutWhenHeadMove(rot: Int(data[9]))
        }
        if(data[13]<90){
            let mo = Float((90-Int(data[13])))
            var d10 = Float(data[10])-mo
            if(d10>data_servos[10].maxA){
                d10 = data_servos[10].maxA
            }
            if(d10<data_servos[10].minA){
                d10 = data_servos[10].minA
            }
            var d11 = Float(data[11])+mo
            if(d11>data_servos[11].maxA){
                d11 = data_servos[11].maxA
            }
            if(d11<data_servos[11].minA){
                d11 = data_servos[11].minA
            }
            data[10] = sfun_rotoeCutWhenHeadMove(rot: Int(d10))
            data[11] = sfun_rotoeCutWhenHeadMove(rot: Int(d11))
            data[1] = sfun_rotoeCutWhenHeadMove(rot: sfun_cutRoteHead(org: Int(data[1])-Int(mo), index: 1))
            data[5] = sfun_rotoeCutWhenHeadMove(rot: sfun_cutRoteHead(org: Int(data[5])-Int(mo), index: 5))
            //print("转头小于减值：\(mo) | 转头：\(data[13])")
        }
        if(data[13]>90){
            let mo = Float((Int(data[13])-90))
            var d10 = Float(data[10])+mo
            if(d10>data_servos[10].maxA){
                d10 = data_servos[10].maxA
            }
            if(d10<data_servos[10].minA){
                d10 = data_servos[10].minA
            }
            var d11 = Float(data[11])-mo
            if(d11>data_servos[11].maxA){
                d11 = data_servos[11].maxA
            }
            if(d11<data_servos[11].minA){
                d11 = data_servos[11].minA
            }
            data[10] = sfun_rotoeCutWhenHeadMove(rot: Int(d10))
            data[11] = sfun_rotoeCutWhenHeadMove(rot: Int(d11))
            data[0] = sfun_rotoeCutWhenHeadMove(rot: sfun_cutRoteHead(org: Int(data[0])-Int(mo), index: 0))
            data[4] = sfun_rotoeCutWhenHeadMove(rot: sfun_cutRoteHead(org: Int(data[4])-Int(mo), index: 4))
            //print("转头大于减值：\(mo) | 转头：\(data[13])")
        }
        //15 (name:"头部左右" , currentAngle: 90, minD:0.7, maxD:2.3, minA: 60, maxA: 120),
        data.append(checkAngleSafeOut(putin:self.headRoteOrg[2], nu: 15))
        if(data[15]>92 || data[15]<88){
            data[0] = sfun_rotoeCutWhenHeadMove(rot: Int(data[0]))
            data[1] = sfun_rotoeCutWhenHeadMove(rot: Int(data[1]))
            data[4] = sfun_rotoeCutWhenHeadMove(rot: Int(data[4]))
            data[5] = sfun_rotoeCutWhenHeadMove(rot: Int(data[5]))
            data[8] = sfun_rotoeCutWhenHeadMove(rot: Int(data[8]))
            data[9] = sfun_rotoeCutWhenHeadMove(rot: Int(data[9]))
            data[10] = sfun_rotoeCutWhenHeadMove(rot: Int(data[10]))
            data[11] = sfun_rotoeCutWhenHeadMove(rot: Int(data[11]))
        }
        //16 Servos(name:"左肩上下" , currentAngle: 90, minD:-5, maxD:5, minA: 40, maxA: 140),
        data.append(UInt8(180-Int(data[15])))
        //17 Servos(name:"右肩上下" , currentAngle: 90, minD:-5, maxD:5, minA: 40, maxA: 140),
        data.append(data[15])
        //18 Servos(name:"左肩前后" , currentAngle: 90, minD:-5, maxD:5, minA: 40, maxA: 140),
        data.append(data[14])
        //19 Servos(name:"右肩前后" , currentAngle: 90, minD:-5, maxD:5, minA: 40, maxA: 140),
        data.append(data[14])
        //20 Servos(name:"呼吸频率" , currentAngle: 90, minD:-5, maxD:5, minA: 10, maxA: 170)
        data.append(90)
        //20 Servos(name:"舌头伸缩" , currentAngle: 90, minD:-5, maxD:5, minA: 10, maxA: 170)
        data.append(90)
        return data
    }
    //数据减值
    func sfun_cutRoteHead(org:Int,index:Int) -> Int {
        var re:Int = org
        if(org<Int(data_servos[index].minA)){
            re = Int(data_servos[index].minA)
        }
        if(org>Int(data_servos[index].maxA)){
            re = Int(data_servos[index].maxA)
        }
        return re
    }
    //数据偏移减量
    func sfun_rotoeCutWhenHeadMove(rot:Int) -> UInt8 {
        var re:UInt8 = 90
        if(rot>92){
            re = UInt8(92 + (rot-92)*(rot/90))
        }
        if(rot<88){
            re = UInt8(88 - (88-rot)*((90-rot)/90))
        }
        return re
    }
    
    //实时发送数据
    @objc func sendingDatasTo() -> Void {
        if(isActive){
            //print("头部旋转：\(self.sendingData[13]) | 头部前后:\(self.sendingData[14]) | 嘴部张合:\(self.sendingData[12])")
            //print("头部旋转：\(self.sendingData[13]) | 头部前后:\(self.sendingData[14]) | 头部左右:\(self.sendingData[15]) | 嘴部张合:\(self.sendingData[12])")
            //print("左侧眉毛：\(self.sendingData[0]) | 右侧眉毛：\(self.sendingData[1])")
            //print("左上眼皮：\(self.sendingData[4]) | 右上眼皮：\(self.sendingData[5])")
            //print("左唇上下：\(self.sendingData[8]) | 右唇上下:\(self.sendingData[9]) | 左唇前后:\(self.sendingData[10])| 右唇前后:\(self.sendingData[11])")
            if ptManager.isConnected {
                /*for n in self.sendingData {
                    ptManager.sendObject(object: n, type: PTType.number.rawValue)
                }*/
                ptManager.sendObject(object: self.sendingData, type: PTType.array.rawValue)
            } else {
                //print(" no contact ")
            }
        }
    }
    
    //数据传输用
    func peertalk(shouldAcceptDataOfType type: UInt32) -> Bool {
        return true
    }
    
    func peertalk(didReceiveData data: Data, ofType type: UInt32) {
        let count = data.convert() as! Int
        print("\(count)")
    }
    
    func peertalk(didChangeConnection connected: Bool) {
        print("Connection: \(connected)")
    }
    
    //角度安全检测
    func checkAngleSafeOut(putin:Float,nu:Int) -> UInt8 {
        var res = putin
        if(res<data_servos[nu].minD){
            res = data_servos[nu].minD
        }
        if(res>data_servos[nu].maxD){
            res = data_servos[nu].maxD
        }
        return fgmap(x: res, in_min: data_servos[nu].minD, in_max: data_servos[nu].maxD, out_min: data_servos[nu].minA, out_max: data_servos[nu].maxA)
    }
    
    //数组平均数
    func getAvgNumber(array:[Float]) -> Float {
        var op:Float = 0.0
        for p in array {
            op += p
        }
        return op / Float(array.count)
    }
    
    //角度计算
    func cgmap(x:CGFloat, in_min:CGFloat, in_max:CGFloat, out_min:CGFloat, out_max:CGFloat) -> Int {
        return Int((x - in_min) * (out_max - out_min) / (in_max - in_min) + out_min);
    }
    //角度计算
    func fgmap(x:Float, in_min:Float, in_max:Float, out_min:Float, out_max:Float) -> UInt8 {
        return UInt8((x - in_min) * (out_max - out_min) / (in_max - in_min) + out_min);
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
}
