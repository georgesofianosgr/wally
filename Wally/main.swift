//
//  main.swift
//  Wally
//
//  Created by George Sofianos on 24/1/22.
//

import Foundation
import SQLite

let arguments = CommandLine.arguments
if(arguments.count < 2) {
    print("usage: wally /absolute/path/to/image.jpg")
    exit(1)
}
let imgPath = arguments[1]
changeWallpaper(imgPath);

enum Errors: Error {
    case fileNotExists(String)
}

// TODO: support relative path
func changeWallpaper(_ imagePath: String) {
    do {
        let homeDirURL = FileManager.default.homeDirectoryForCurrentUser
        let path = "\(homeDirURL.path)/Library/Application Support/Dock/desktoppicture.db"
        let db = try Connection(path)
        
        if(!FileManager.default.fileExists(atPath: imagePath)) {
            throw Errors.fileNotExists("Provided file does not exist")
        }
        
        let selectedDataId = try handleBackgroundData(db, imagePath: imagePath)
        try handlePreferences(db, dataId: selectedDataId)
        restartDock()

    } catch {
        print (error)
    }
}


func handleBackgroundData(_ db: Connection, imagePath: String) throws -> Int64 {
    let data = Table("data")
    let value = Expression<String?>("value")
    
    var selectedDataId : Int64 = 0;
    
    for row in try db.prepare("SELECT rowid, value FROM data") {
        let rowId = row[0] as? Int64
        let value = row[1] as? String
        if value == imagePath {
            selectedDataId = rowId ?? 0;
        }
    }
    
    if selectedDataId == 0 {
//        print("inserting \(imagePath) to data")
        selectedDataId = try db.run(data.insert(value <- imagePath))
    }
    
//    print("selectedDataId: \(selectedDataId)")
    return selectedDataId;
}

func handlePreferences(_ db: Connection, dataId: Int64) throws {
    let picturesTable = Table("pictures")
    let preferencesTable = Table("preferences")
    try db.transaction {
        try db.run(preferencesTable.delete())

        for (index,_) in try db.prepare(picturesTable).enumerated() {
            let keyCol = Expression<Int>("key")
            let dataIdCol = Expression<Int64>("data_id");
            let pictureIdCol = Expression<Int64>("picture_id");

//            print(dataId)
            try db.run(preferencesTable.insert(keyCol <- 1, dataIdCol <- dataId, pictureIdCol <- Int64(index+1)))
        }
    }
}

func restartDock() {
    let task = Process()
    task.launchPath = "/usr/bin/killall"
    task.arguments = ["Dock"]
    task.launch()
    task.waitUntilExit()
}


