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

var managedContext :NSManagedObjectContext = NSManagedObjectContext(concurrencyType:.mainQueueConcurrencyType)

class MainViewController: UIViewController,CLLocationManagerDelegate,MKMapViewDelegate {
    //MARK:IBOutlet Properties
    @IBOutlet weak var txtLattitude: UITextField!
    @IBOutlet weak var txtlongitude: UITextField!
    @IBOutlet weak var txtspeed: UITextField!
    @IBOutlet weak var txtTotalHardbreaks: UITextField!
    @IBOutlet weak var txtMessage: UITextField!
    @IBOutlet weak var imageView: UIImageView!
    //MARK:Local Variables
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
    var tempString4: String = " | Id | CurrentSpeed (MPH)| Previous Speed (MPH) | Lattitude | Longitude | Hardbreak |"
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
    
    //MARK:View LifeCycle
    override func viewDidLoad() {
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
        isStart = true
        //Creation of mapView :
        mapView.frame = CGRect(x: 20, y: 350, width: self.view.frame.width - 40, height: 300)
        self.view.addSubview(mapView)
        self.mapView.delegate = self
        //------------
        hardBreakTimer = Timer.scheduledTimer(timeInterval: 1.5, target: self, selector: #selector(hardBreakApplied), userInfo: nil, repeats: true)
        managedContext  = DBManager.saveDatainContext()
        mapdataNew = DBManager.fetchCarDetailsRecordsFromCoreData1(context: managedContext)
        print(tempString2)
        print(tempString3)
        print(tempString4)
        for mapdetails in mapdataNew!{
            count = count + 1
            print("|\(count) |\((mapdetails.currentSpeed)!) | \((mapdetails.previousSpeed)!) |\((mapdetails.lattitude)!)|\((mapdetails.longitude)!) |\((mapdetails.hardBreak)!) |\(mapdetails.sharpTurn!)")
            print("-------------------------------------------------------------------------------------------------------")
        }
        updateTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(mapviewfunction), userInfo: nil, repeats: true)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
    }
 
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        hardBreakTimer?.invalidate()
        updateTimer?.invalidate()
        locationManager.stopUpdatingLocation()
    }
    
    
    //MARK: Timers Methods
    @objc internal func mapviewfunction(){
        print("called after 4 mins")
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
    }

    @objc internal func hardBreakApplied(){
        isStart = false
        let diffrence =  self.oldSpeed - self.speed
        if abs(diffrence) > 9.0{
            self.isHardBreakApplied = true
            self.hardBreakCount  = self.hardBreakCount + 1
            self.txtTotalHardbreaks.text = "\(self.hardBreakCount)"
        }else{
            self.isHardBreakApplied = false
        }
        DBManager.storeCarDetailsToCoreData(context: managedContext, currentSpeed: "\(String(format: "%.1f", self.speed))", previousSpeed: "\(String(format: "%.1f", self.oldSpeed))", lattitide: "\((self.currentLocationLattiude))", longitude: "\((self.currentLocationLongitude))", hardbrek: "\(isHardBreakApplied)", sharpTurn: "\(isSharpTurn)")
        
        mapdataNew = DBManager.fetchCarDetailsRecordsFromCoreData1(context: managedContext)
    }
    // Configure an integer only number formatter
    static let numberFormatter: NumberFormatter =  {
        let mf = NumberFormatter()
        mf.minimumFractionDigits = 0
        mf.maximumFractionDigits = 0
        return mf
    }()
    
    //MARK: SharpTurn Calculations
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
//                self.imageView.transform = CGAffineTransform(rotationAngle: angle)
            }
        }
    }
    //MARK: OrientationAdjustment
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
        if updateTimer != nil && backgroundTask == .invalid {
            registerBackgroundTask()
        }
    }
}
