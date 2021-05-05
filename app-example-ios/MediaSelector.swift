//
// MediaData.swift
// app-example-ios
//
// Copyright (c) 2021 nacamar GmbH - Ybrid®, a Hybrid Dynamic Live Audio Technology
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//

import UIKit
import YbridPlayerSDK

fileprivate struct MediaData {
    let label:String
    var url:String
    var editable:Bool = false
}

class MediaSelector: NSObject, UIPickerViewDelegate, UITextFieldDelegate {
    
    let pickerData:MediaPickerData = MediaPickerData()
    let urlPicker: UIPickerView
    let urlField: UrlField
    let setMediaEndpoint:(MediaEndpoint?) -> ()
    
    init(urlPicker: UIPickerView, urlField: UrlField, endpoint:@escaping (MediaEndpoint?) -> ()) {
        self.urlPicker = urlPicker
        self.urlField = urlField
        self.setMediaEndpoint = endpoint
    }
    
    // MARK: delegate methods
    
    /// on select station
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        let selected = pickerData.urls[row]
        Logger.shared.notice("\(selected.label) selected")
        
        self.urlField.text = selected.url
        if selected.editable {
            self.urlField.enable(placeholder: "enter URL here")
        } else {
            self.urlField.disable()
        }
        
        if self.urlField.isValidUrl, let uri = self.urlField.text {
            self.setMediaEndpoint(MediaEndpoint(mediaUri: uri))
        } else {
            setMediaEndpoint(nil)
        }
    }

    /// on end edit url
    func textFieldDidEndEditing(_ textField: UITextField) {
        let row = urlPicker.selectedRow(inComponent: 0)
        
        if urlField.isValidUrl, let uri = urlField.text {
            pickerData.urls[row].url = uri
            setMediaEndpoint(MediaEndpoint(mediaUri: urlField.text))
        }
    }
    
    /// on edit custom url ("manually" called by view controller)
    func urlEditChanged() -> Bool {
        guard let text = urlField.text, !text.isEmpty else {
            let row = urlPicker.selectedRow(inComponent: 0)
            pickerData.urls[row].url = ""
            setMediaEndpoint(nil)
            return false
        }
        setMediaEndpoint(nil)
        return urlField.isValidUrl
    }

    
    // urlPicker.reloadAllComponents() should satisfy seeing white text color in urlPicker - except for iOS 12.4
    // this is the only way I found to set the color of the url picker entries on iOS 12.4!
    func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
        let title = pickerData.urls[row].label
        let pickerFont = (urlField as UITextField).font!
        let myTitle = NSAttributedString(string: title, attributes: [NSAttributedString.Key.font:UIFont(name: pickerFont.fontName, size: pickerFont.pointSize)!,NSAttributedString.Key.foregroundColor:UIColor.white])
        return myTitle
    }
}


class MediaPickerData: NSObject, UIPickerViewDataSource {
    
    fileprivate var urls:[MediaData] = [] // radios are added from streams.txt
    fileprivate let customUrlLabel = "custom URL"
    
    override init() {
        super.init()
        if let pathToFile = Bundle.main.path(forResource: "streams", ofType: "txt") {
            urls.append(contentsOf: loadUrls(path: pathToFile))
        }
        urls.append(MediaData(label:customUrlLabel, url:"", editable: true))
    }
    
    private func loadUrls(path:String) -> [MediaData]{
        var labelUrls:[MediaData] = []
        let fileContent = try! String(contentsOfFile: path, encoding: String.Encoding.utf8)
        let dataArray = fileContent.components(separatedBy: "\n")
        for line in dataArray {
            let components = line.split(separator: "=", maxSplits: 1).map(String.init)
            guard components.count == 2 else {
                continue
            }
            let label=components[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let url=components[1].trimmingCharacters(in: .whitespacesAndNewlines)
            labelUrls.append(MediaData(label:label,url:url))
        }
        return labelUrls
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return urls.count
    }
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return urls[row].label
    }
    
}


class UrlField: UITextField {
    
    func enable(placeholder: String) {
        self.isEnabled = true
        self.backgroundColor = UIColor(white: 0.4, alpha: 0.3 )
        self.textColor = UIColor.white
        self.attributedPlaceholder = NSAttributedString(string:placeholder, attributes: [NSAttributedString.Key.foregroundColor:UIColor.lightGray])
    }
    
    func disable() {
        self.isEnabled = false
        self.backgroundColor = UIColor(white: 0.0, alpha: 0.3 )
        self.textColor = UIColor.gray
    }
    
    var url:URL? { get {
        guard let text = text else {
            return nil
        }
        
        let urlString = text.trimmingCharacters(in: CharacterSet.whitespaces)
            .addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)
        if let urlEncoded = urlString, let url = URL(string: urlEncoded) {
            return url
        }
        return nil
    }}
    
    var isValidUrl:Bool {
        guard let url = url else { return false }
        return UIApplication.shared.canOpenURL(url)
    }
}

