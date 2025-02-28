//
//  FameLadySquad.swift
//  NFTY
//
//  Created by Varun Kohli on 7/18/21.
//

import Foundation
import Cache
import BigInt
import PromiseKit
import Web3
import Web3ContractABI
import UIKit


class FameLadySquad_Contract : ContractInterface {
  
  private var imageCache = try! DiskStorage<BigUInt, UIImage>(
    config: DiskConfig(name: "FameLadySquad.ImageCache",expiry: .never),
    transformer:TransformerFactory.forImage())
  
  private var imageCacheHD = try! DiskStorage<BigUInt, UIImage>(
    config: DiskConfig(name: "FameLadySquad.ImageCacheHD",expiry: .never),
    transformer:TransformerFactory.forImage())
  
  private var pricesCache : [UInt : ObservablePromise<NFTPriceStatus>] = [:]
  
  let name = "FameLadySquad"
  
  let contractAddressHex = "0xf3E6DbBE461C6fa492CeA7Cb1f5C5eA660EB1B47"
  
  var tradeActions: TokenTradeInterface? = OpenSeaTradeApi(contract: try! EthereumAddress(hex: "0xf3E6DbBE461C6fa492CeA7Cb1f5C5eA660EB1B47", eip55: false))
  
  class IpfsImageEthContract : Erc721Contract {
    
    // till 4443 inclusive, it is QmRRRcbfE3fTqBLTmmYMxENaNmAffv7ihJnwFkAimBP4Ac
    // after it is QmTwNwAerqdP3LXcZnCCPyqQzTyB26R5xbsqEy5Vh3h6Dw
    
    static func imageOfData(_ data:Data?) -> Media.IpfsImage? {
      return data
        .flatMap {
          UIImage(data:$0)
            .flatMap { image_hd in
              image_hd
                .jpegData(compressionQuality: 0.1)
                .flatMap { UIImage(data:$0) }
                .map { Media.IpfsImage(image:.image($0),image_hd:.image(image_hd)) }
            }
        }
    }
    
    func image(_ tokenId:BigUInt) -> Promise<Data?> {
      return Promise { seal in
        
        let url = tokenId < 4444
          ? URL(string:"https://nft-1.mypinata.cloud/ipfs/QmRRRcbfE3fTqBLTmmYMxENaNmAffv7ihJnwFkAimBP4Ac/\(tokenId).png")!
          : URL(string:"https://nft-1.mypinata.cloud/ipfs/QmTwNwAerqdP3LXcZnCCPyqQzTyB26R5xbsqEy5Vh3h6Dw/\(tokenId).png")!
        
        var request = URLRequest(url:url)
        request.httpMethod = "GET"
        
        ImageLoadingSemaphore.wait()
        print("calling \(request.url!)")
        URLSession.shared.dataTask(with: request,completionHandler:{ data, response, error -> Void in
          // print(data,response,error)
          ImageLoadingSemaphore.signal()
          // Compress these images on download, as they cause jitter in UI scrolling
          seal.fulfill(data)
        }).resume()
      }
    }
  }
  
  private func download(_ tokenId:BigUInt) -> ObservablePromise<Media.IpfsImage?> {
    return ObservablePromise(promise: Promise { seal in
      DispatchQueue.global(qos:.userInteractive).async {
        switch(try? self.imageCache.object(forKey:tokenId),try? self.imageCacheHD.object(forKey:tokenId)) {
        case (.some(let image),.some(let image_hd)):
          seal.fulfill(Media.IpfsImage(image: .image(image),image_hd: .image(image_hd)))
        case (_,.none),(.none,_):
          self.ethContract.image(tokenId)
            .done(on:DispatchQueue.global(qos: .background)) {
              let image = IpfsImageEthContract.imageOfData($0)
              image.flatMap {
                if case .image(let image) = $0.image {
                  try? self.imageCache.setObject(image, forKey: tokenId)
                }
                if case .image(let image_hd) = $0.image_hd {
                  try? self.imageCacheHD.setObject(image_hd, forKey: tokenId)
                }
              }
              seal.fulfill(image)
            }
            .catch {
              print($0)
              seal.fulfill(nil)
            }
        }
      }
    })
  }
  
  let ethContract = IpfsImageEthContract(address:"0xf3E6DbBE461C6fa492CeA7Cb1f5C5eA660EB1B47")
  
  func getEventsFetcher(_ tokenId: BigUInt) -> TokenEventsFetcher? {
    return ethContract.getEventsFetcher(tokenId)
  }
  
  func getRecentTrades(onDone: @escaping () -> Void,_ response: @escaping (NFTWithPrice) -> Void) {
    ethContract.transfer.done {
      $0.fetch(onDone:onDone) { log in
        
        let res = try! web3.eth.abi.decodeLog(event:Erc721Contract.Transfer,from:log);
        let tokenId = res["tokenId"] as! BigUInt
        let isMint = res["from"] as! EthereumAddress == EthereumAddress(hexString:ETH_ADDRESS)!
        
        response(NFTWithPrice(
          nft:NFT(
            address:self.contractAddressHex,
            tokenId:tokenId,
            name:self.name,
            media:.ipfsImage(Media.IpfsImageLazy(tokenId:tokenId, download: self.download))),
          blockNumber:log.blockNumber.map { .ethereum($0) },
          indicativePrice:.lazy {
            ObservablePromise(
              promise:
                self.ethContract.eventOfTx(transactionHash:log.transactionHash,eventType:isMint ? .minted : .bought)
                .map {
                  let price = priceIfNotZero($0?.value);
                  return NFTPriceStatus.known(
                    NFTPriceInfo(
                      wei:price,
                      blockNumber:log.blockNumber.map { .ethereum($0) },
                      type: isMint ? .minted : price.map { _ in TradeEventType.bought } ?? TradeEventType.transfer))
                }
            )
          }
        ))
      }
    }.catch { print($0); onDone() }
  }
  
  func refreshLatestTrades(onDone: @escaping () -> Void,_ response: @escaping (NFTWithPrice) -> Void) {
    ethContract.transfer.done {
      $0.updateLatest(onDone:onDone) { index,log in
        let res = try! web3.eth.abi.decodeLog(event:Erc721Contract.Transfer,from:log);
        let tokenId = res["tokenId"] as! BigUInt
        let isMint = res["from"] as! EthereumAddress == EthereumAddress(hexString:ETH_ADDRESS)!
        
        response(NFTWithPrice(
          nft:NFT(
            address:self.contractAddressHex,
            tokenId:tokenId,
            name:self.name,
            media:.ipfsImage(Media.IpfsImageLazy(tokenId:tokenId, download: self.download))),
          blockNumber:log.blockNumber.map { .ethereum($0) },
          indicativePrice:.lazy {
            ObservablePromise(
              promise:
                self.ethContract.eventOfTx(transactionHash:log.transactionHash,eventType:isMint ? .minted : .bought)
                .map {
                  let price = priceIfNotZero($0?.value);
                  return NFTPriceStatus.known(
                    NFTPriceInfo(
                      wei:price,
                      blockNumber:log.blockNumber.map { .ethereum($0) },
                      type: isMint ? .minted : price.map { _ in TradeEventType.bought } ?? TradeEventType.transfer))
                }
            )
          }
        ))
      }
    }.catch { print($0); onDone() }
  }
  
  func getNFT(_ tokenId: BigUInt) -> NFT {
    NFT(
      address:self.contractAddressHex,
      tokenId:tokenId,
      name:self.name,
      media:.ipfsImage(Media.IpfsImageLazy(tokenId:tokenId, download: self.download)))
  }
  
  func getToken(_ tokenId: UInt) -> NFTWithLazyPrice {
    
    NFTWithLazyPrice(
      nft:getNFT(BigUInt(tokenId)),
      getPrice: {
        switch(self.ethContract.pricesCache[tokenId]) {
        case .some(let p):
          return p
        case .none:
          let p =
            self.ethContract.getTokenHistory(tokenId)
            .map(on:DispatchQueue.global(qos:.userInteractive)) { (event:TradeEventStatus) -> NFTPriceStatus in
              switch(event) {
              case .trade(let event):
                return NFTPriceStatus.known(NFTPriceInfo(wei:priceIfNotZero(event.value),blockNumber:event.blockNumber,type:event.type))
              case .notSeenSince(let since):
                return NFTPriceStatus.notSeenSince(since)
              }
            }
          let observable = ObservablePromise(promise: p)
          DispatchQueue.main.async {
            self.ethContract.pricesCache[tokenId] = observable
          }
          return observable
        }
      }
    )
  }
  
  func getOwnerTokens(address: EthereumAddress, onDone: @escaping () -> Void, _ response: @escaping (NFTWithLazyPrice) -> Void) {
    ethContract.ethContract.balanceOf(address:address)
      .then(on:DispatchQueue.global(qos: .userInteractive)) { tokensNum -> Promise<Void> in
        if (tokensNum <= 0) {
          return Promise.value(())
        } else {
          return when(
            fulfilled:
              Array(0...tokensNum-1).map { index -> Promise<Void> in
                return
                  self.ethContract.ethContract.tokenOfOwnerByIndex(address: address,index:index)
                  .map { tokenId in
                    return self.getToken(UInt(tokenId))
                  }.done {
                    response($0)
                  }
              }
          )
        }
      }.done(on:DispatchQueue.global(qos:.userInteractive)) { (promises:Void) -> Void in
        onDone()
      }.catch {
        print ($0)
        onDone()
      }
  }
  
  func ownerOf(_ tokenId: BigUInt) -> Promise<UserAccount?> {
    return ethContract.ownerOf(tokenId)
  }
  
  func indicativeFloor() -> Promise<PriceUnit?> {
    return AlchemyApi.GetFloor.indicativeFloor(self.contractAddressHex)
  }
  
  var vaultContract: CollectionVaultContract? = nil
  
  func floorFetcher(_ collection:Collection) -> PagedTokensFetcher? {
    return OpenSeaFloorFetcher.make(collection:collection)
  }
  
}
