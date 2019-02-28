//
//  ViewController.swift
//  AutoDJ
//
//  Created by Ho, Tsung Wei on 1/17/19.
//  Copyright © 2019 Bose ASD. All rights reserved.
//
import UIKit
import CoreLocation
import MapKit
import AVFoundation
import CoreData
import SpotifyLogin
import MessageUI

var managedContext :NSManagedObjectContext = NSManagedObjectContext(concurrencyType:.mainQueueConcurrencyType)

class MainViewController: UIViewController,CLLocationManagerDelegate,MKMapViewDelegate,MFMailComposeViewControllerDelegate{
    //MARK:IBOutlet Properties
    @IBOutlet weak var txtLattitude: UITextField!
    @IBOutlet weak var txtlongitude: UITextField!
    @IBOutlet weak var txtspeed: UITextField!
    @IBOutlet weak var txtTotalHardbreaks: UITextField!
    @IBOutlet weak var txtMessage: UITextField!
    @IBOutlet weak var imageView: UIImageView!
    //MARK:Local Variables----------
    var count :Int = 0
    let locationManager = CLLocationManager()
    var currentCoordinate: CLLocationCoordinate2D!
    var tempLattitude : Double  = Double()
    var tempLongitude : Double = Double()
    var steps = [MKRoute.Step]()
    let speechSynthesizer = AVSpeechSynthesizer()
    var stepCounter = 0
    private var locationList: [CLLocation] = []
    private var hardBreakTimer: Timer?
    private var updateTimer: Timer?
    var speed :Double = 0.0
    var oldSpeed :Double = 0.0
    var hardBreakCount: Double = 0.0
    var isHardBreakApplied : Bool = false
    var mapdataNew :[MapdataNew]? = [MapdataNew]()
    var countCalls:Int = 0
    var tempString2 : String = "                    MapListDetails                                  "
    var tempString3: String = "------------------------------------------------------------------------|"
    var tempString4: String = " | Id | CurrentSpeed (MPH)| Previous Speed (MPH) | Lattitude | Longitude | Hardbreak |Track Id |TrackName |Album Name | Artist Name |Tempo | Energy| Speechiness | Loudness | Instrumental"
    var tempString5 :String = "------------------------------------------------------------------------"
    var latestLocation: CLLocation? = nil
    var yourLocationBearing: CGFloat { return latestLocation?.bearingToLocationRadian(self.yourLocation) ?? 0 }
    var yourLocation: CLLocation = CLLocation()
    var newheadingdirection :CGFloat = CGFloat()
    var oldheadingdirection :CGFloat = 0.0
    var headingCallback: ((CLLocationDirection) -> ())? = nil
    var isSharpTurn: Bool = false
    var timeAtPress: Date = Date()
    var mapView :MKMapView = MKMapView()
    var currentLocationLattiude :Double = Double()
    var currentLocationLongitude :Double = Double()
    var isStart: Bool = false
    var energy:Double = 0.0
    var tempo :Double = 0.0
    var loudness : Double = 0.0
    var instrumnetal : Double = 0.0
    var speechiness : Double = 0.0
    var acousticness : Double = 0.0
    @IBOutlet weak var exportToCsv: UIButton!
    //-----MARK: Spotify Related Properties
    @IBOutlet weak var imageview1: UIImageView!
    @IBOutlet weak var btnnext: SpotifyLoginButton!
    @IBOutlet weak var btnprev: SpotifyLoginButton!
    var isAccessTokenAvailble :Bool = false
    
    var btnSpotify: UIButton!
    var artistArrayName :Array<String> = Array<String>()
    var listArray :Array<AudioFeatureModel> = Array<AudioFeatureModel>()
    
    var trackName:String = ""
    var trackId:String = ""
    var artistName:String = ""
    var albumName:String = ""
    
   var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    //MARK:View LifeCycle
    override func viewDidLoad() {
       // let appDelegate: AppDelegate? = UIApplication.shared.delegate as? AppDelegate
       // appDelegate?.applicationDidEnterBackground(UIApplication)
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        //Creation of mapView :
        mapView.frame = CGRect(x: 20, y: 350, width: self.view.frame.width - 40, height: 300)
        self.view.addSubview(mapView)
        self.mapView.delegate = self
        //-------
        
        locationManager.requestAlwaysAuthorization()
        locationManager.delegate = self
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        isStart = true
        //Creation of mapView :
        mapView.frame = CGRect(x: 20, y: 350, width: self.view.frame.width - 40, height: 200)
        self.view.addSubview(mapView)
        self.mapView.delegate = self
        //------------
        hardBreakTimer = Timer.scheduledTimer(timeInterval: 1.5, target: self, selector: #selector(hardBreakApplied), userInfo: nil, repeats: true)
        
          registerBackgroundTask()
        managedContext  = DBManager.saveDatainContext()
        mapdataNew = DBManager.fetchCarDetailsRecordsFromCoreData1(context: managedContext)
        print(tempString2)
        print(tempString3)
        print(tempString4)
        for mapdetails in mapdataNew!{
            count = count + 1
            print("|\(count) |\((mapdetails.currentSpeed)!) | \((mapdetails.previousSpeed)!) |\((mapdetails.lattitude)!)|\((mapdetails.longitude)!) |\((mapdetails.hardBreak)!) |\(mapdetails.sharpTurn!)|\(mapdetails.trackiD!)|\(mapdetails.trackName!)|\(mapdetails.albumName!)|\(mapdetails.artistName!) | \(mapdetails.tempo) | \(String(describing: mapdetails.energy)) | \(String(describing: mapdetails.speechiness)) | \(mapdetails.loudness) | \(String(describing: mapdetails.instrumentalness)) ")
            print("-------------------------------------------------------------------------------------------------------")
        }
        updateTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(mapviewfunction), userInfo: nil, repeats: true)
        addSpotifyButton()
        self.imageview1.isHidden = true
        
       
        
        NotificationCenter.default.addObserver(self, selector: #selector(reinstateBackgroundTask), name: UIApplication.didBecomeActiveNotification, object: nil)
        
        
        self.btnnext.isHidden = true
        self.btnprev.isHidden = true
        
    }
    func registerBackgroundTask() {
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
        assert(backgroundTask != .invalid)
    }
    
    func endBackgroundTask() {
        print("Background task ended.")
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }
    
    @objc func reinstateBackgroundTask() {
        if hardBreakTimer != nil && backgroundTask == .invalid {
            registerBackgroundTask()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
    }
    
   
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    //-------MARK:Add Spoitfy Button
    func addSpotifyButton(){
        let button = SpotifyLoginButton(viewController: self, scopes: [.userReadTop, .userReadPlaybackState, .userModifyPlaybackState, .userReadCurrentlyPlaying])
        self.view.addSubview(button)
        self.btnSpotify = button
        self.btnSpotify.frame = CGRect(x: 100, y: self.txtMessage.frame.origin.y + 80, width: 200, height: 40)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(loginSuccessful),
                                               name: .SpotifyLoginSuccessful,
                                               object: nil)
    }
    //MARK:IBOutlet and Action Properties -------------------
    @IBAction func btnNextTapped(_ sender: Any) {
        SpotifyDataController.shared.skipToNextTrack() { data in
            sleep(1)
            self.updateCurrentlyPlaying()
        }
    }
    @IBAction func btnPrevTapped(_ sender: Any) {
        SpotifyDataController.shared.skipToPreviousTrack() { data in
            sleep(1)
            self.updateCurrentlyPlaying()
        }
    }
    @IBAction func exportTocsvTapped(_ sender: Any) {
        taskCsv()
        addEmailPresentViewController()
    }
    
    //MARK:Timers Methods-----------------------------------
    
    @objc func loginSuccessful() {
        print("LOGIN COMPLETED")
        self.btnSpotify?.isHidden = true
        self.btnnext.isHidden = false
        self.btnprev.isHidden = false
        self.imageview1.isHidden = false
        isAccessTokenAvailble = true
        self.updateCurrentlyPlaying()
    }
    
    @objc internal func mapviewfunction(){
        print("called after 4 mins")
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
    }
    //-------MARK:Sharp Break and storing all data in Core Data
    @objc internal func hardBreakApplied(){
        isStart = false
       
        let diffrence =  self.oldSpeed - self.speed
        if abs(diffrence) > 20.0{
            self.isHardBreakApplied = true
            self.hardBreakCount  = self.hardBreakCount + 1
            self.txtTotalHardbreaks.text = "\(self.hardBreakCount)"
        }else{
            self.isHardBreakApplied = false
        }
//
//        let timestamp = NSDate().timeIntervalSince1970
//        let myTimeInterval = TimeInterval(timestamp)
//
//        
        let date = Date()
        let dateFormatterPrint = DateFormatter()
        dateFormatterPrint.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        print(dateFormatterPrint.string(from: date))
        
        let time = "\(dateFormatterPrint.string(from: date))"
        
        print(time)
        if isAccessTokenAvailble == false{
            
        }else{
           
            
            self.updateCurrentlyPlaying()
        }
      DBManager.storeCarDetailsToCoreData(context: managedContext, currentSpeed: "\(String(format: "%.1f", self.speed))",                previousSpeed: "\(String(format: "%.1f", self.oldSpeed))", lattitide: "\((self.currentLocationLattiude))", longitude: "\((self.currentLocationLongitude))", hardbrek: "\(isHardBreakApplied)", sharpTurn: "\(isSharpTurn)", trackid: "\(trackId)", trackname: trackName, artistName: artistName, albumName: albumName, energy: "\(String(describing: self.energy))", tempo: "\(String(describing: self.tempo))", speechiness: "\(String(describing: self.speechiness))", instruemetal: "\(String(describing: self.instrumnetal))", loudness: "\(String(describing: self.loudness))",timeStamp: "\(time)")
        
        mapdataNew = DBManager.fetchCarDetailsRecordsFromCoreData1(context: managedContext)
    }
    // Configure an integer only number formatter
    static let numberFormatter: NumberFormatter =  {
        let mf = NumberFormatter()
        mf.minimumFractionDigits = 0
        mf.maximumFractionDigits = 0
        return mf
    }()
    
    //MARK: SharpTurn Calculations-----------------
    public func findAngle(){
        self.headingCallback = { newHeading in
            func computeNewAngle(with newAngle: CGFloat) -> CGFloat {
                let heading: CGFloat = {
                    let originalHeading = self.yourLocationBearing - newAngle.degreesToRadians
                    switch UIDevice.current.orientation {
                    case .faceDown: return -originalHeading
                    default: return originalHeading
                    }
                }()
                
                return CGFloat(self.orientationAdjustment().degreesToRadians + heading)
            }
            /// print(newHeading)
            UIView.animate(withDuration: 0.5) {
                let angle = computeNewAngle(with: CGFloat(newHeading))
                print(angle)
                self.imageView.transform = CGAffineTransform(rotationAngle: angle)
            }
        }
    }
    //MARK: OrientationAdjustment------------------------------
    private func orientationAdjustment() -> CGFloat {
        let isFaceDown: Bool = {
            switch UIDevice.current.orientation {
            case .faceDown: return true
            default: return false
            }
        }()
        
        let adjAngle: CGFloat = {
            switch UIApplication.shared.statusBarOrientation {
            case .landscapeLeft:  return 90
            case .landscapeRight: return -90
            case .portrait, .unknown: return 0
            case .portraitUpsideDown: return isFaceDown ? 180 : -180
            }
        }()
        return adjAngle
    }
    
    //MARK:MapView Delegate Methods---------------------------
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        locationManager.stopUpdatingLocation()
        guard let currentLocation = locations.first else { return }
        currentCoordinate = currentLocation.coordinate
        yourLocation = currentLocation
        if currentLocation.coordinate.longitude - tempLongitude == 0 && currentLocation.coordinate.latitude - tempLattitude == 0{
        }else{
            tempLongitude = currentLocation.coordinate.longitude
            tempLattitude = currentLocation.coordinate.latitude
            self.currentLocationLattiude = currentLocation.coordinate.latitude
            self.currentLocationLongitude = currentLocation.coordinate.longitude
            txtLattitude.text = "\((currentLocation.coordinate.latitude))"
            txtlongitude.text = "\(currentLocation.coordinate.longitude)"
            //  print(currentLocation.speed)
            let kmh = currentLocation.speed / 1000.0 * 60.0 * 60.0
            self.oldSpeed = self.speed
            self.txtMessage.text = "old \(self.oldSpeed)"
            if kmh > 0{
                self.speed = kmh * 0.62
            }
            if speed > 0.0 {
                self.txtspeed.text = "\(speed) MPH"
            }else{
                self.txtspeed.text = "0.0"
            }
            mapView.userTrackingMode = .followWithHeading
        }
        
    }
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        locationManager.stopUpdatingHeading()
        var diffrenceangle = CGFloat(newHeading.trueHeading) - self.oldheadingdirection
        self.oldheadingdirection = CGFloat(newHeading.trueHeading)
        headingCallback?(newHeading.trueHeading)
        print("second 1")
        findAngle()
        
        if isStart == true{
            
            diffrenceangle = 0
        }else{
            if diffrenceangle > 50 {
                print("diffrenceangle",diffrenceangle)
                isSharpTurn = true
            }else{
                isSharpTurn = false
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("⚠️ Error while updating location " + error.localizedDescription)
    }
    
    //------------MARK:SpoitfyApi-------------------------
    
    @objc func updateCurrentlyPlaying() {
        SpotifyDataController.shared.getCurrentlyPlayingTrack() { data in
            guard let data = data else { return }
            guard let trackItem = data["item"] as? [String: Any] else { return }
            guard let album = trackItem["album"] as? [String: Any] else { return }
            self.albumName = "\((album["name"])!)"
            guard let images = album["images"] as? [AnyObject] else { return }
            guard let imageURLString = images[0]["url"] as? String else { return }
            guard let trackName = trackItem["name"] as? String else { return }
            guard let trackId = trackItem["id"] as? String else { return }
            guard let artistsList = trackItem["artists"] as? [AnyObject] else { return }
            var stringartistName : String = String()
            self.artistArrayName.removeAll()
            for itmet in artistsList{
                stringartistName = (itmet["name"] as? String)!
                self.artistArrayName.append(stringartistName)
            }
            let joined = self.artistArrayName.joined(separator: "/")
            self.artistName = joined
            self.trackId = trackId
            self.trackName = trackName
            self.listArray.removeAll()
            SpotifyDataController.shared.getAudioTrack(id: trackId) {  data in
                guard let data1 = data else { return }
                self.listArray.append(AudioFeatureModel(dictData: data1))
                self.energy = self.listArray[0].energy
                self.tempo = self.listArray[0].tempo
                self.loudness = self.listArray[0].loudness
                self.instrumnetal = self.listArray[0].instrumentalness
                self.acousticness  = self.listArray[0].acousticness
                
                print(self.energy)
                print(self.tempo)
                print(self.loudness)
                print(self.instrumnetal)
                print(self.acousticness)
            }
            let imageURL = URL(string: imageURLString)
            DispatchQueue.global().async {
                let data = try? Data(contentsOf: imageURL!)
                DispatchQueue.main.async {
                    //self.imageview1.image = UIImage(data: data!)
                }
            }
        }
        
    }
    //--------------CSV Creation of File --------------
    func taskCsv(){
        
        let fileName = "Details.csv"
        let path = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
        var csvText = "Date,CurrentSpeedtime(MPH),Previous Speed(MPH),Lattitude,Longitude,Hardbreak,Sharpturn,Track Id,TrackName,Artist Name,Album Name,Energy,Tempo,Loudness\n"
        var indexcount = 0
        for mapdetails in mapdataNew! {
            indexcount = indexcount + 1
            
            let newLine = "\((mapdetails.timeStamp)!),\((mapdetails.currentSpeed)!), \((mapdetails.previousSpeed)!),\((mapdetails.lattitude)!),\((mapdetails.longitude)!),\((mapdetails.hardBreak)!),\(mapdetails.sharpTurn!),\(mapdetails.trackiD!),\(mapdetails.trackName!),\(mapdetails.artistName!),\(mapdetails.albumName!),\(mapdetails.energy!),\(mapdetails.tempo!),\(mapdetails.loudness!)\n"
            csvText.append(contentsOf: newLine)
        }
        do {
            try csvText.write(to: path!, atomically: true, encoding: String.Encoding.utf8)
        } catch {
            print("Failed to create file")
            print("\(error)")
        }
        
    }
    
    //-------MARK:Message Delegation-------------(mailComposeController:didFinishWithResult:error:)
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        self.dismiss(animated: true, completion: nil)
    }
    
    
    //-------Send Mail To respective Email id
    func addEmailPresentViewController(){
        
        let fileName = "Details.csv"
        let path = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
        do {
            if MFMailComposeViewController.canSendMail() {
                let emailController = MFMailComposeViewController()
                emailController.mailComposeDelegate = self
                emailController.setToRecipients([])
                emailController.setSubject("Details.csv data export")
                emailController.setMessageBody("Hi,\n\nThe .csv data export is attached", isHTML: false)
                emailController.addAttachmentData(try Data(contentsOf: (path)!), mimeType: "text/csv", fileName: "Details.csv")
                self.present(emailController, animated: true, completion: nil)
            }
        } catch {
            
            print("Failed to create file")
            print("\(error)")
        }
    }
    
    
}
