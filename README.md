# C³ framework
is Chained-Cubic-Cell or Chained-Cauchy-Cell.  
An implementation of probabilistic multi-layered perceptron.  
All connection weights and biases depend on [Stable distribution](https://wikipedia.org/wiki/Stable_distribution).   
The signal propagation gets randomly determined.  
[Cauchy distribution](https://wikipedia.org/wiki/Cauchy_distribution) is employed for current implementation.   
  
Their units can take only binary states, 0 and 1, meaning NOT FIRED and FIRED,   
similat to general multi-layered perceptron.  
The common of learning law is similar to the [BP](https://wikipedia.org/wiki/Backpropagation) and [RTRL](https://en.wikipedia.org/wiki/Backpropagation) for general neural networks.  
They however employ several improved techniques such as sign propagation for binary unit.  

This framework employes [Metal](https://developer.apple.com/library/mac/documentation/Metal/Reference/MetalFrameworkReference/) and [Core Data](https://developer.apple.com/library/watchos/documentation/Cocoa/Conceptual/CoreData/).  
The computation is accelerated by [GPGPU](https://wikipedia.org/wiki/General-purpose_computing_on_graphics_processing_units)   and their learnt layers' relationships get automatically stored with [ORM](https://wikipedia.org/wiki/Object-relational_mapping).  
