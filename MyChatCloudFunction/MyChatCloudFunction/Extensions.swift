//
//  Extensions.swift
//  MyChatCloudFunction
//
//  Created by Guillermo Peñarando Sánchez on 24/07/2020.
//  Copyright © 2020 Guillermo Peñarando Sánchez. All rights reserved.
//

import Foundation
import UIKit

//esta extension sirve para ahorrar lineas de codigo comprimiendo "posiciones" de varias palabras en una sola, agilizando y permitiendo una lectura del codigo mas facil.
extension UIView {
    
    public var width: CGFloat {
        return self.frame.size.width
    }
    
    public var height: CGFloat {
        return self.frame.size.height
    }
    
    public var top: CGFloat {
        return self.frame.origin.y
    }
    
    public var bottom: CGFloat {
        return self.frame.size.height + self.frame.origin.y
    }
    
    public var left: CGFloat {
        return self.frame.origin.x
    }
    
    public var right: CGFloat {
        return self.frame.size.width + self.frame.origin.x
    }
}

