//
//  ViewController.swift
//  sandbox
//
//  Created by Kota Nakano on 6/3/16.
//
//

import Cocoa
import C3
import MNIST
class ViewController: NSViewController {

	var context: Context! = nil
	var layer: CAMetalLayer! = nil
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		context = try?Context()
		layer = context?.newRenderLayer()
		
		view.layer = layer
		view.wantsLayer = true
		
		let vertices: [Float] = [
			-1,-1,
			-1, 1,
			 1,-1,
			 1, 1,
			-1, 1,
		]
		
		let image: Image = Image.t10k[Int(arc4random_uniform(UInt32(Image.t10k.count)))]
		let img: [UInt8] = image.pixel
		let width: Int = image.cols
		let height: Int = image.rows
		print(image.label)
		
		let tex: MTLTexture = context.newTexture2D(MTLPixelFormat.R8Unorm, width: width, height: height, mipmap: false)
		tex.replaceRegion(MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: UnsafePointer<Void>(img), bytesPerRow: sizeof(UInt8)*width)
		
		let sampler: MTLSamplerState = context.newSampler()
		
		context.newRenderCommand(layer: layer, shader: ("planeview_vert", "planeview_frag")) {
			$0.setVertexBytes(vertices, length: sizeof(Float)*vertices.count, atIndex: 0)
			$0.setVertexBytes([u_char(0), u_char(1)], length: sizeof(u_char)*2, atIndex: 1)
			$0.setFragmentTexture(tex, atIndex: 0)
			$0.setFragmentSamplerState(sampler, atIndex: 0)
			$0.drawPrimitives(MTLPrimitiveType.TriangleStrip, vertexStart: 0, vertexCount: 5)
		}
		
		// Do any additional setup after loading the view.
	}

	override var representedObject: AnyObject? {
		didSet {
		// Update the view, if already loaded.
		}
	}


}

