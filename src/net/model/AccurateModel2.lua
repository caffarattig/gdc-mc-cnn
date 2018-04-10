require 'torch'
require 'nn'
require 'cudnn'

require 'net/criterion/BCECriterion2'
require 'net/builder/mc-cnn/AccurateBuilder'

local AccurateModel2, parent = torch.class('AccurateModel2', 'AccurateBuilder')

local function load_params(self, opt)
   self.params = {}
   local p = self.params
   p.n_conv_layers = opt.cl                           -- number of convolutional layers
   p.n_feature_maps = opt.fm                          -- number of convolutional layer feature maps
   p.kernel_sizes = opt.kss                           -- kernel sizes
   p.n_fully_connected_layers = opt.fcl               -- fully connected layers
   p.n_fully_connected_units = opt.nu                 -- number of units in fully connected layers
   p.n_input_planes = opt.color == 'rgb' and 3 or 1
   
   p.batch_size = opt.bs
   p.epochs = opt.epochs
   
   p.learning_rate = 0.003
   p.learning_rate_decay = 0.0
   p.momentum = 0.9
   p.nesterov = true
   p.dampening = 0.0
   p.weight_decay = 1e-4
   
   if opt.ds == 'Kitti2012' then
      p.L1=5
      p.cbca_i1=2
      p.cbca_i2=0
      p.tau1=0.13
      p.pi1=1.32
      p.pi2=24.25
      p.sgm_i=1
      p.sgm_q1=3
      p.sgm_q2=2
      p.alpha1=2
      p.tau_so=0.08
      p.blur_sigma=5.99
      p.blur_t=6
   elseif opt.ds == 'Kitti2015' then
      p.L1=5
      p.cbca_i1=2
      p.cbca_i2=4
      p.tau1=0.03
      p.pi1=2.3
      p.pi2=24.25
      p.sgm_i=1
      p.sgm_q1=3
      p.sgm_q2=2
      p.alpha1=1.75
      p.tau_so=0.08
      p.blur_sigma=5.99
      p.blur_t=5
   end
   
   for k,v in pairs(self.params) do print(k, v) end
end

function AccurateModel2:__init(opt)
   parent.__init(self)
   load_params(self, opt)
   self.name = self:getName(opt)
   self.path = opt.storage .. '/net/mc/'
   self.criterion = nn.BCECriterion2():cuda()
end