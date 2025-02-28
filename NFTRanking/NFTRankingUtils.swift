//
//  NFTRankingUtils.swift
//  NFTY
//
//  Created by Varun Kohli on 7/21/21.
//

import Foundation

typealias TokenDistance = [Float]

struct Erc721TokenAttribute : Codable {
  let trait_type : String
  let value : String
  
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    trait_type = try container.decode(String.self, forKey: .trait_type)
    do {
      value = try String(container.decode(Int.self, forKey: .value))
    } catch {
      do {
        value = try String(container.decode(Double.self, forKey: .value))
      } catch {
        value = try container.decode(String.self, forKey: .value)
      }
    }
    
  }
}

struct Erc721TokenUriData : Codable {
  let image : String
  let attributes : [Erc721TokenAttribute]
}

struct Erc721TokenData : Codable {
  let image : Data
  let attributes : [Erc721TokenAttribute]
}


func getDocumentsDirectory() -> URL {
  let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
  return paths[0]
}

func getResourcesDirectory() -> URL {
  return getDocumentsDirectory()
    .appendingPathComponent("../")
    .appendingPathComponent("Github")
    .appendingPathComponent("NFTY")
    .appendingPathComponent("NFTY")
    .appendingPathComponent("Resources")
}

func getDistancesFilename(_ collectionName:String) -> URL {
  return getResourcesDirectory()
    .appendingPathComponent("\(collectionName)Distances.json")
}

func getAttributePercentilesFilename(_ collectionName:String) -> URL {
  return getResourcesDirectory()
    .appendingPathComponent("\(collectionName)AttributePercentiles.json")
}

func getAttributeRankFilename(_ collectionName:String) -> URL {
  return getResourcesDirectory()
    .appendingPathComponent("\(collectionName)_attributeRanks.json")
}

func getAttributeScoresFilename(_ collectionName:String) -> URL {
  return getResourcesDirectory()
    .appendingPathComponent("\(collectionName)_attributeScores.json")
}

func getFeaturesFilename(_ collectionName:String) -> URL {
  return getResourcesDirectory()
    .appendingPathComponent("\(collectionName)Features.json")
}


func getNeighborsFilename(_ collectionName:String) -> URL {
  return getResourcesDirectory()
    .appendingPathComponent("\(collectionName)_nearestTokens.json")
}

func getRarityRankFilename(_ collectionName:String) -> URL {
  return getResourcesDirectory()
    .appendingPathComponent("\(collectionName)_rarityRanks.json")
}

func getImageDirectory(collectionName:String,imagesDir:String) -> URL {
  return
    getDocumentsDirectory()
    .appendingPathComponent("../")
    .appendingPathComponent("Github")
    .appendingPathComponent("NFTY")
    .appendingPathComponent("data")
    .appendingPathComponent("Images")
    .appendingPathComponent(collectionName)
    .appendingPathComponent(imagesDir)
}

func getImageFileName(collectionName:String,imagesDir:String,_ tokenId:UInt) -> URL {
  return getImageDirectory(collectionName:collectionName,imagesDir: imagesDir)
    .appendingPathComponent("\(tokenId).png")
  
}

func getAttributesDirectory(collectionName:String,attributesDir:String) -> URL {
  return
    getDocumentsDirectory()
    .appendingPathComponent("../")
    .appendingPathComponent("Github")
    .appendingPathComponent("NFTY")
    .appendingPathComponent(attributesDir)
  
}

func getAttributesFileName(collectionName:String,attributesDir:String,_ tokenId:UInt) -> URL {
  return getAttributesDirectory(collectionName:collectionName,attributesDir: attributesDir)
    .appendingPathComponent("\(tokenId).json")
}

func loadImageData(collectionName:String,imagesDir:String,_ tokenId:UInt) -> Data {
  let filename = getImageFileName(collectionName:collectionName,imagesDir:imagesDir,tokenId)
  return try! Data(contentsOf: filename)
}

func saveJSON<T: Encodable>(_ filename:URL,_ obj : T) -> Void? {
  let encoder = JSONEncoder()
  let data = try? encoder.encode(obj)
  print("Saving file=\(filename)")
  return data.flatMap { try! $0.write(to: filename) }
}

func loadJSON<T:Decodable>(_ filename:URL) -> T {
  let data = try! Data(contentsOf: filename)
  let decoder = JSONDecoder()
  return try! decoder.decode(T.self, from: data)
}

func loadJSONObject(_ filename:URL) -> [String:Any] {
  let data = try! Data(contentsOf: filename)
  return try! JSONSerialization.jsonObject(with: data, options: .mutableContainers) as! [String:Any]
}
