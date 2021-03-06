require 'torch'
require 'image'
require 'math'

require 'expert/MatchingExpert'
require 'expert/PrePostProcessingExpert'
require 'expert/PostProcessingExpert'
require 'expert/DisparityExpert'
require 'expert/RefinementExpert'
require 'expert/StoringExpert'

local PredictingExpert = torch.class('PredictingExpert')

function PredictingExpert:__init(network, dataset, opt, path)
   self.network = network
   self.dataset = dataset
   self.opt = opt
   self.path = path
   self.matching = MatchingExpert()
   self.pre_post_processing = PrePostProcessingExpert(opt)
   self.post_processing = PostProcessingExpert()
   self.disparity = DisparityExpert()
   self.refinement = RefinementExpert()
   self.storing = StoringExpert(opt.temp)
end

function PredictingExpert:predict(img, disp_max, directions, make_cache)

   local vox
   
   local final_disp_max = math.floor(disp_max*self.opt.red_factor)
   --local img_scaled = image.scale(img, math.floor(img.width / 2), math.floor(img.height / 2))
   -- compute matching cost
   if self.opt.use_cache then
      vox = torch.load(('%s_%s.t7'):format(self.path, img.id)):cuda()
   else
      vox = self.matching:match(self.network, img.x_batch,
         final_disp_max, directions):cuda()
      if make_cache then
         torch.save(('%s_%s.t7'):format(self.path, img.id), vox)
      end
   end
   collectgarbage()
   
   local disp, conf, t, vox_simple
   -- post_process
   if self.opt.alternate_proc then
      disp, vox, conf, t = self.disparity:disparityImage(vox, self.gdn)
      disp = self.pre_post_processing:cv_erode(disp)
      
      sm_active = (self.opt.sm_terminate ~= 'cnn') and (self.opt.sm_terminate ~= 'cbca1') and (self.opt.sm_terminate ~= 'sgm') and (self.opt.sm_terminate ~= 'cbca2')
   else
      if self.opt.just_refinement then
         disp, vox, conf, t = self.disparity:disparityImage(vox, self.gdn)
         
         sm_active = true
      else
         vox = self.post_processing:process(vox, img.x_batch, final_disp_max, self.network.params, self.dataset, self.opt.sm_terminate, self.opt.sm_skip, directions)
         
         collectgarbage()
      
         -- disparity image
         disp, vox, conf, t = self.disparity:disparityImage(vox, self.gdn)
         if self.opt.alternate_after_proc then
            disp = self.pre_post_processing:cv_erode(disp)
         end
      end
   end
   -- pred after post process
   local vox_simple = vox:clone()
   
   --local disp_filtered2 = self.pre_post_processing:depth_filter(disp)
   --self.storing:save_png_noerror(self.dataset, img, disp_filtered2, disp_max, 'post')

   -- refinement
   disp = self.refinement:refine(disp, vox_simple, self.network.params, self.dataset, self.opt.sm_skip ,self.opt.sm_terminate, final_disp_max, conf, t.t1, t.t2, sm_active)

   return disp[2]

end