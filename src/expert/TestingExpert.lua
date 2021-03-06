require 'torch'
require 'cutorch'
require 'image'

require 'expert/PredictingExpert'
require 'expert/StoringExpert'

local TestingExpert = torch.class('TestingExpert')

function TestingExpert:__init(dataset, network, gdn, opt)
   self.dataset = dataset
   self.network = network
   self.gdn = gdn
   self.opt = opt
   self.path = ('%s/cache/%s/%s'):format(opt.storage, self.dataset.name, self.network.name)
   
   self.storing = StoringExpert(opt.temp)
end

local function calcErr(self, pred, dispnoc, mask)
   local pred_good = torch.CudaTensor(dispnoc:size())
   local pred_bad = torch.CudaTensor(dispnoc:size())
   dispnoc:add(-1, pred):abs()
   pred_bad:gt(dispnoc, self.dataset.err_at):cmul(mask)
   pred_good:le(dispnoc, self.dataset.err_at):cmul(mask)

   local err = pred_bad:sum() / mask:sum()

   return err, pred_bad, pred_good
end

function TestingExpert:test(range, showall, make_cache)
   local err_sum = 0

   local opt = self.opt
   local directions = self.dataset.name == 'mb' and {-1} or {1, -1}
   
   local predicting_expert = PredictingExpert(self.network, self.dataset, opt, self.path) 

   local runtime_sum = 0
   for i, idx in ipairs(range) do
      xlua.progress(i-1, #range)
      local img = self.dataset:getTestSample(idx, false, opt.red_factor, opt.full_res_check)
      local disp_max = img.disp_max or self.dataset.disp_max

      cutorch.synchronize()
      sys.tic()

      local pred = predicting_expert:predict(img, disp_max, directions, make_cache)
      pred = pred:div(opt.red_factor)
      
      collectgarbage()

      cutorch.synchronize()
      local runtime = sys.toc()
      
      runtime_sum = runtime_sum + runtime
      
      local float_pred = torch.FloatTensor():resize(pred:size(1), pred:size(2), img.orig_x0_height, img.orig_x0_width):zero()
      if opt.full_res_check and opt.red_factor ~= 1 then
         local temp_pred = nn.utils.recursiveType(pred, 'torch.FloatTensor')
         float_pred[1]:copy(image.scale(temp_pred[1], img.orig_x0_width, img.orig_x0_height))
         collectgarbage()
      end
      

      local dispnoc = img.dispnoc
      -- creates a mask with all the non-zero objects of the disparity
      local mask = torch.CudaTensor(dispnoc:size()):ne(dispnoc, 0)

      err, pred_bad, pred_good = calcErr(self, (opt.full_res_check and opt.red_factor ~= 1) and float_pred:cuda() or pred, dispnoc:clone(), mask)
      err_sum = err_sum + err

      if showall then
         print('\n' .. img.id, runtime, err .. '\n')
      end
      if self.opt.save_img then
         self.storing:save_png(self.dataset, img, disp_max, pred, pred_bad, pred_good, mask, self.network.name)
      end
      collectgarbage()
   end
   xlua.progress(#range, #range)
   return err_sum / #range, runtime_sum / #range
end