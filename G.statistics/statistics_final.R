# preparations

library(lme4)
library(lattice)
library(ggplot2)
library(gridExtra)
# library(utils)


# library(stats)
# library(graphics)

library(car)
library(dplyr)
library(emmeans)
# library(fastDummies)

options(scipen = 20)

# read in data
data<- read.delim('F://Brainwave_exp2/processed/dataframe.tsv', sep="\t")
# as factor
data$pid <-as.factor(data$pid)
data$trial <- as.factor(data$trial)
data$time <- factor(data$time, levels=c("baseline", "preFOG", "FOG"))# change order of time
data$trigger <- factor(data$trigger, levels=c("turn", "doorway"))
data$type <- factor(data$type, levels=c("trembling", "akinesia", "shuffling", "stop", "trigger"))
data$DT <- factor(data$DT, levels=c("nDT", "cDT", "mDT"))
data$condition <- factor(data$condition, levels=c("FOG", "stop", "congr", "trigger"))

# remove the "congruent" trials
data <- droplevels(subset(data, data$condition!="congr"))
# exclude PD5
data <- droplevels(subset(data, data$pid !="110005"))

# inspect data
head(data)
tail(data)
str(data)
summary(data)
data[which(is.na(data$HR)==TRUE), ] #think about what to do with the na's
data[which(is.na(data$FI_R)==TRUE), ] #think about what to do with the na's

# combine trembling and shuffling
data$type <-recode(data$type, shuffling = "trembling")

# randomly assign stop events as 'akinesia' or 'trembling'
stps_trig<-which(data$condition=="stop"|data$condition=="trigger")
values<-sample(c("trembling", "akinesia"), length(stps_trig)/3, replace=TRUE)
values_rep<-rep(values, each=3)
data$type <- droplevels(replace(data$type, stps_trig, values))
levels(data$type)

# 1, FIRST MODEL: baseline vs preFOG vs FOG
# only select the FOG events
data_FOG <- droplevels(subset(data, data$condition=='FOG'))
str(data_FOG)
summary(data_FOG)

# fix contrasts: https://stats.idre.ucla.edu/r/library/r-library-contrast-coding-systems-for-categorical-variables/#forward
contrast.time<-matrix(c(0, 1, 0, 0, 0, 1), nrow=3, ncol=2, dimnames=list(c("baseline", "preFOG", "FOG"), c("preFOGvsBL", "FOGvsBL"))) # dummy coding/treatment contrast
contrasts(data_FOG$time)<-contrast.time
contrasts(data_FOG$time)# see also: https://arxiv.org/pdf/1807.10451.pdf

contrast.trigger<-matrix(c(-1/2, 1/2), nrow=2, ncol=1, dimnames=list(c("turn", "doorway"), c("doorwayvsturn"))) # simple coding/sum contrast
contrasts(data_FOG$trigger)<-contrast.trigger
contrasts(data_FOG$trigger)

contrast.type<-matrix(c(-1/2, 1/2), nrow=2, ncol=1, dimnames=list(c("trembling", "akinesia"), c("akinesiavstrembling"))) # simple coding
contrasts(data_FOG$type)<-contrast.type
contrasts(data_FOG$type)

contrast.DT<-matrix(c(-1/3, 1/3, -1/3, -1/3, -1/3, 1/3), nrow=3, ncol=2, dimnames=list(c("nDT", "cDT", "mDT"), c("cDTvsnDT", "mDTvsnDT"))) # simple coding
contrasts(data_FOG$DT)<-contrast.DT
contrasts(data_FOG$DT)

# build lme model
mod1_FI <- lmer(FI_R ~ time*trigger + time*type + time*DT + (1|pid), data=data_FOG) #no random effect for trial, because makes no sense for FI and introduces heteroscedascity. Maybe also no random slope? --> no singular fit anymore
mod1_mFI <- lmer(mFI_R ~ time*trigger + time*type + time*DT + (1|pid), data=data_FOG) #no random effect for trial, because makes no sense for FI and introduces heteroscedascity. Maybe also no random slope? --> no singular fit anymore
mod1_HR <- lmer(HR ~ time*trigger + time*type + time*DT + (1|pid) + (1|trial), data=data_FOG) #random effect (1+time|trial) does not work because number random effects = number of observations (see also instructions holy grail workshop)
summary(mod1_FI)
summary(mod1_mFI)
summary(mod1_HR)

# check assumptions
plot(mod1_FI, type = c('p', 'smooth')) # fitted vs. residual: by useing 3 seconds-windows --> looks already bit better and also no interaction effect for time and DT anymore
qqPlot(resid(mod1_FI, scaled = TRUE))
hist(resid(mod1_FI))

plot(fitted(mod1_FI), residuals(mod1_FI))
densityplot(resid(mod1_FI, scaled=TRUE))
densityplot(resid(mod1_FI), group=data_FOG$time, auto.key=TRUE)
densityplot(resid(mod1_FI), group=data_FOG$trigger, auto.key=TRUE)
densityplot(resid(mod1_FI), group=data_FOG$type, auto.key=TRUE)
densityplot(resid(mod1_FI), group=data_FOG$DT, auto.key=TRUE)

sum(abs(resid(mod1_FI, scaled = TRUE)) > 2) / length(resid(mod1_FI)) #  (should be no more than 0.05)
sum(abs(resid(mod1_FI, scaled = TRUE)) > 2.5) / length(resid(mod1_FI)) # 
sum(abs(resid(mod1_FI, scaled = TRUE)) > 3) / length(resid(mod1_FI)) #  (everything here could be an outlier and should be checked)
data_FOG[which(abs(resid(mod1_FI, scaled=TRUE))>3), ]

plot(mod1_mFI, type = c('p', 'smooth')) # fitted vs. residual: by useing 3 seconds-windows --> looks already bit better and also no interaction effect for time and DT anymore
qqPlot(resid(mod1_mFI, scaled = TRUE))
hist(resid(mod1_mFI))

plot(mod1_HR, type = c('p', 'smooth')) # fitted vs. residual
qqPlot(resid(mod1_HR, scaled = TRUE))
hist(resid(mod1_HR))

# anova
Anova(mod1_FI, test = 'F', type = 3) #F tests with Roger-Kenward adjustment of degrees of freedom
Anova(mod1_mFI, test = 'F', type = 3) #F tests with Roger-Kenward adjustment of degrees of freedom
Anova(mod1_HR, test = 'F', type = 3) #F tests with Roger-Kenward adjustment of degrees of freedom

# post hoc test: https://aosmith.rbind.io/2019/03/25/getting-started-with-emmeans/
#! only correct for multiple comparison within each group
FI_type<-emmeans(mod1_FI, trt.vs.ctrl~time|type) # default = Dunnett adjustment
mFI_type<-emmeans(mod1_mFI, trt.vs.ctrl~time|type) # default = Dunnett adjustment
FI_trigger<-emmeans(mod1_FI, trt.vs.ctrl~time|trigger)
mFI_trigger<-emmeans(mod1_mFI, trt.vs.ctrl~time|trigger)
FI_DT<-emmeans(mod1_FI, trt.vs.ctrl~time|DT)
mFI_DT<-emmeans(mod1_mFI, trt.vs.ctrl~time|DT)

emmeans(mod1_HR, trt.vs.ctrl~time) 
HR_type<-emmeans(mod1_HR, trt.vs.ctrl~time|type) # default = Dunnett adjustment
HR_trigger<-emmeans(mod1_HR, trt.vs.ctrl~time|trigger)
HR_DT<-emmeans(mod1_HR, trt.vs.ctrl~time|DT)
emmeans(mod1_HR, pairwise~trigger)
emmeans(mod1_HR, pairwise~DT)

# create dataframe for plotting
plot_FItype<-as.data.frame(FI_type$contrasts)
plot_FItype<-rename(plot_FItype, level=type)
plot_FItype$variable<-'FI'
plot_FItype$factor<-'type'

plot_FItrigger<-as.data.frame(FI_trigger$contrasts)
plot_FItrigger<-rename(plot_FItrigger, level=trigger)
plot_FItrigger$variable<-'FI'
plot_FItrigger$factor<-'trigger'

plot_FIDT<-as.data.frame(FI_DT$contrasts)
plot_FIDT<-rename(plot_FIDT, level=DT)
plot_FIDT$variable<-'FI'
plot_FIDT$factor<-'DT'

plot_mFItype<-as.data.frame(mFI_type$contrasts)
plot_mFItype<-rename(plot_mFItype, level=type)
plot_mFItype$variable<-'mFI'
plot_mFItype$factor<-'type'

plot_mFItrigger<-as.data.frame(mFI_trigger$contrasts)
plot_mFItrigger<-rename(plot_mFItrigger, level=trigger)
plot_mFItrigger$variable<-'mFI'
plot_mFItrigger$factor<-'trigger'

plot_mFIDT<-as.data.frame(mFI_DT$contrasts)
plot_mFIDT<-rename(plot_mFIDT, level=DT)
plot_mFIDT$variable<-'mFI'
plot_mFIDT$factor<-'DT'

plot_HRtype<-as.data.frame(HR_type$contrast)
plot_HRtype<-rename(plot_HRtype, level=type)
plot_HRtype$variable<-'heart rate'
plot_HRtype$factor<-'type'

plot_HRtrigger<-as.data.frame(HR_trigger$contrast)
plot_HRtrigger<-rename(plot_HRtrigger, level=trigger)
plot_HRtrigger$variable<-'heart rate'
plot_HRtrigger$factor<-'trigger'

plot_HRDT<-as.data.frame(HR_DT$contrasts)
plot_HRDT<-rename(plot_HRDT, level=DT)
plot_HRDT$variable<-'heart rate'
plot_HRDT$factor<-'DT'

plot_all=rbind(plot_FItype, plot_FItrigger, plot_FIDT, plot_mFItype, plot_mFItrigger, plot_mFIDT, plot_HRtype, plot_HRtrigger, plot_HRDT)
plot_all$factor <- factor(plot_all$factor, levels=c("type", "trigger", "DT"))
plot_all$variable <- factor(plot_all$variable, levels=c("FI", "mFI", "heart rate"))
plot_all$level<-recode(plot_all$level, doorway="narrow passage")
plot_all$level<-recode(plot_all$level, nDT="noDT")

# actual plotting
ggplot(plot_all) + theme_light() + facet_grid(variable ~ factor, scales="free_x", drop=FALSE) + aes(x=level, y=estimate, color=contrast)+ geom_pointrange(aes(ymin=estimate-SE, ymax=estimate+SE), position=position_dodge(width=0.5)) + scale_color_manual(values=c( '#F0925A', '#D55E00'))+ geom_hline(yintercept=0)+ ylab('estimated contrast')+theme(axis.title.x=element_blank(), plot.title=element_text(hjust = 0.5),legend.position = 'top') + ggtitle('Model 1: baseline vs preFOG vs FOG')



# 2. SECOND MODEL: FOG vs stopping and FOG vs normal gait event

# recalculate HR change as the difference in mean HR of during FOG - preFOG
data_preFOG<-droplevels(subset(data, data$time=='preFOG'))
data_duringFOG<-droplevels(subset(data, data$time=='FOG'))
data_cond <- droplevels(subset(data, data$time=='FOG'))
data_cond$HRCh<- data_duringFOG$HR - data_preFOG$HR
#data_cond$FICH<-data_duringFOG$mFI_R - data_preFOG$mFI_R
str(data_cond)
summary(data_cond)

# fix contrasts
contrasts(data_cond$type)<-contrast.type
contrasts(data_cond$type)

contrasts(data_cond$trigger)<-contrast.trigger
contrasts(data_cond$trigger)

contrasts(data_cond$DT)<-contrast.DT
contrasts(data_cond$DT)

contrast.cond<-matrix(c(0, -1, 0, 0, 0, -1), nrow=3, ncol=2,dimnames=list(c("FOG", "stop", "trigger"), c("stopvsFOG", "triggervsFOG"))) 
contrasts(data_cond$condition)<-contrast.cond
contrasts(data_cond$condition)

# build the model
mod2_HR <- lmer(HRCh ~ condition*trigger + condition*DT + condition*type + (1|pid), data=data_cond) #random effect (1+time|trial) does not work because number random effects = number of observations (see also instructions holy grail workshop)
mod2_FI <- lmer(FI_R ~ condition*trigger + condition*DT + condition*type + (1|pid), data=data_cond) 
mod2_mFI <- lmer(mFI_R ~ condition*trigger + condition*DT + condition*type + (1|pid), data=data_cond) 
summary(mod2_FI)
summary(mod2_mFI)
summary(mod2_HR)

# check assumptions
plot(mod2_FI, type = c('p', 'smooth')) # fitted vs. residual
qqPlot(resid(mod2_FI, scaled = TRUE))
hist(resid(mod2_FI))

plot(mod2_mFI, type = c('p', 'smooth')) # fitted vs. residual
qqPlot(resid(mod2_mFI, scaled = TRUE))
hist(resid(mod2_mFI))

plot(mod2_HR, type = c('p', 'smooth')) # fitted vs. residual
qqPlot(resid(mod2_HR, scaled = TRUE))
hist(resid(mod2_HR))

# anova
Anova(mod2_FI, test = 'F', type = 3)
Anova(mod2_mFI, test = 'F', type = 3)
Anova(mod2_HR, test = 'F', type = 3)

# post hoc test
FI_type<-emmeans(mod2_FI, trt.vs.ctrl~condition|type, reverse=TRUE)
FI_trigger<-emmeans(mod2_FI, trt.vs.ctrl~condition|trigger, reverse=TRUE)
FI_DT<-emmeans(mod2_FI, trt.vs.ctrl~condition|DT, reverse=TRUE)
emmeans(mod2_FI, trt.vs.ctrl~type, reverse=TRUE)

mFI_type<-emmeans(mod2_mFI, trt.vs.ctrl~condition|type, reverse=TRUE)
mFI_trigger<-emmeans(mod2_mFI, trt.vs.ctrl~condition|trigger, reverse=TRUE)
mFI_DT<-emmeans(mod2_mFI, trt.vs.ctrl~condition|DT, reverse=TRUE)

HR_type<-emmeans(mod2_HR, trt.vs.ctrl~condition|type, reverse=TRUE)
HR_trigger<-emmeans(mod2_HR, trt.vs.ctrl~condition|trigger,reverse=TRUE)
HR_DT<-emmeans(mod2_HR, trt.vs.ctrl~condition|DT,reverse=TRUE)
emmeans(mod2_HR, trt.vs.ctrl~trigger,reverse=TRUE)
emmeans(mod2_HR, trt.vs.ctrl~DT,reverse=TRUE)
emmeans(mod2_HR, trt.vs.ctrl~type,reverse=TRUE)

# create dataframe for plotting
plot_FItype<-as.data.frame(FI_type$contrasts)
plot_FItype<-rename(plot_FItype, level=type)
plot_FItype$variable<-'FI'
plot_FItype$factor<-'type'

plot_FItrigger<-as.data.frame(FI_trigger$contrasts)
plot_FItrigger<-rename(plot_FItrigger, level=trigger)
plot_FItrigger$variable<-'FI'
plot_FItrigger$factor<-'trigger'

plot_FIDT<-as.data.frame(FI_DT$contrasts)
plot_FIDT<-rename(plot_FIDT, level=DT)
plot_FIDT$variable<-'FI'
plot_FIDT$factor<-'DT'

plot_mFItype<-as.data.frame(mFI_type$contrasts)
plot_mFItype<-rename(plot_mFItype, level=type)
plot_mFItype$variable<-'mFI'
plot_mFItype$factor<-'type'

plot_mFItrigger<-as.data.frame(mFI_trigger$contrasts)
plot_mFItrigger<-rename(plot_mFItrigger, level=trigger)
plot_mFItrigger$variable<-'mFI'
plot_mFItrigger$factor<-'trigger'

plot_mFIDT<-as.data.frame(mFI_DT$contrasts)
plot_mFIDT<-rename(plot_mFIDT, level=DT)
plot_mFIDT$variable<-'mFI'
plot_mFIDT$factor<-'DT'

plot_HRtype<-as.data.frame(HR_type$contrast)
plot_HRtype<-rename(plot_HRtype, level=type)
plot_HRtype$variable<-'heart rate'
plot_HRtype$factor<-'type'

plot_HRtrigger<-as.data.frame(HR_trigger$contrast)
plot_HRtrigger<-rename(plot_HRtrigger, level=trigger)
plot_HRtrigger$variable<-'heart rate'
plot_HRtrigger$factor<-'trigger'

plot_HRDT<-as.data.frame(HR_DT$contrasts)
plot_HRDT<-rename(plot_HRDT, level=DT)
plot_HRDT$variable<-'heart rate'
plot_HRDT$factor<-'DT'

plot_all=rbind(plot_FItype, plot_FItrigger, plot_FIDT, plot_mFItype, plot_mFItrigger, plot_mFIDT, plot_HRtype, plot_HRtrigger, plot_HRDT)
plot_all$factor <- factor(plot_all$factor, levels=c("type", "trigger", "DT"))
plot_all$variable <- factor(plot_all$variable, levels=c("FI", "mFI", "heart rate"))
plot_all$level<-recode(plot_all$level, doorway="narrow passage")
plot_all$level<-recode(plot_all$level, nDT="noDT")
plot_all$contrast<-recode(plot_all$contrast, 'FOG - trigger'="FOG - normal gait event")

# actual plotting
ggplot(plot_all) + theme_light() + facet_grid(variable ~ factor, scales="free_x", drop=FALSE) + aes(x=level, y=estimate, color=contrast)+ geom_pointrange(aes(ymin=estimate-SE, ymax=estimate+SE), position=position_dodge(width=0.5)) + scale_color_manual(values=c('#2271B2', '#359B73'))+ geom_hline(yintercept=0)+ ylab('estimated contrast') + theme(axis.title.x=element_blank(), plot.title=element_text(hjust = 0.5),legend.position = 'top') + ggtitle('Model 2: FOG vs stop vs normal gait event')


# plot
plot_FItype<-as.data.frame(FI_type$emmeans)
ggplot(plot_FItype) + aes(x=type, y=emmean, colour=condition) + geom_pointrange(aes(ymin=lower.CL, ymax=upper.CL) ,position=position_dodge(width=0.5)) + scale_color_manual(values=c('#FF0000', '#333FFF', '#33CC33')) + theme(legend.position = 'top') + ylim(0, 7)
plot_FItype<-as.data.frame(FI_type$contrasts)
ggplot(plot_FItype) + aes(x=contrast, y=estimate, colour=type) + geom_pointrange(aes(ymin=estimate-SE, ymax=estimate+SE), position=position_dodge(width=0.5)) + scale_color_manual(values=c('#0072BD', '#D95319')) + theme(legend.position = 'top')+ ylim(-2,3)
plot_mFItype<-as.data.frame(mFI_type$contrasts)
ggplot(plot_mFItype) + aes(x=contrast, y=estimate, colour=type) + geom_pointrange(aes(ymin=estimate-SE, ymax=estimate+SE), position=position_dodge(width=0.5)) + scale_color_manual(values=c('#0072BD', '#D95319')) + theme(legend.position = 'top')+ ylim(-2,3)

plot_FItrigger<-as.data.frame(FI_trigger$emmeans)
ggplot(plot_FItrigger) + aes(x=trigger, y=emmean, colour=condition) + geom_pointrange(aes(ymin=lower.CL, ymax=upper.CL) ,position=position_dodge(width=0.5))+ scale_color_manual(values=c('#FF0000', '#333FFF', '#33CC33'))+ theme(legend.position = 'top')+ ylim(0, 7)
plot_FItrigger<-as.data.frame(FI_trigger$contrasts)
ggplot(plot_FItrigger) + aes(x=contrast, y=estimate, colour=trigger) + geom_pointrange(aes(ymin=estimate-SE, ymax=estimate+SE), position=position_dodge(width=0.5)) + scale_color_manual(values=c('#0072BD', '#D95319')) + theme(legend.position = 'top')+ ylim(-2,3)
plot_mFItrigger<-as.data.frame(mFI_trigger$contrasts)
ggplot(plot_mFItrigger) + aes(x=contrast, y=estimate, colour=trigger) + geom_pointrange(aes(ymin=estimate-SE, ymax=estimate+SE), position=position_dodge(width=0.5)) + scale_color_manual(values=c('#0072BD', '#D95319')) + theme(legend.position = 'top')+ ylim(-2,3)


plot_FIDT<-as.data.frame(FI_DT$emmeans)
ggplot(plot_FIDT) + aes(x=DT, y=emmean, colour=condition) + geom_pointrange(aes(ymin=lower.CL, ymax=upper.CL) ,position=position_dodge(width=0.5))+ scale_color_manual(values=c('#FF0000', '#333FFF', '#33CC33'))+ theme(legend.position = 'top')+ ylim(0, 7)
plot_FIDT<-as.data.frame(FI_DT$contrasts)
ggplot(plot_FIDT) + aes(x=contrast, y=estimate, colour=DT) + geom_pointrange(aes(ymin=estimate-SE, ymax=estimate+SE), position=position_dodge(width=0.5)) + scale_color_manual(values=c('#0072BD', '#D95319', '#EDB120'))+  theme(legend.position = 'top') + ylim(-2,3)
plot_mFIDT<-as.data.frame(mFI_DT$contrasts)
ggplot(plot_mFIDT) + aes(x=contrast, y=estimate, colour=DT) + geom_pointrange(aes(ymin=estimate-SE, ymax=estimate+SE), position=position_dodge(width=0.5)) + scale_color_manual(values=c('#0072BD', '#D95319', '#EDB120'))+  theme(legend.position = 'top') + ylim(-2,3)


plot_HRtype<-as.data.frame(HR_type$emmeans)
ggplot(plot_HRtype) + aes(x=type, y=emmean, colour=condition) + geom_pointrange(aes(ymin=lower.CL, ymax=upper.CL) ,position=position_dodge(width=0.5)) + scale_color_manual(values=c('#FF0000', '#333FFF', '#33CC33')) + theme(legend.position = 'top')+ ylim(-2.5, 2.5)
plot_HRtype<-as.data.frame(HR_type$contrasts)
ggplot(plot_HRtype) + aes(x=contrast, y=estimate, colour=type) + geom_pointrange(aes(ymin=estimate-SE, ymax=estimate+SE)  ,position=position_dodge(width=0.5))  + scale_color_manual(values=c('#0072BD', '#D95319'))  + theme(legend.position = 'top') + ylim(-2, 3)

plot_HRtrigger<-as.data.frame(HR_trigger$emmeans)
ggplot(plot_HRtrigger) + aes(x=trigger, y=emmean, colour=condition) + geom_pointrange(aes(ymin=lower.CL, ymax=upper.CL) ,position=position_dodge(width=0.5))+ scale_color_manual(values=c('#FF0000', '#333FFF', '#33CC33'))+ theme(legend.position = 'top') + ylim(-2.5, 2.5)
plot_HRtrigger<-as.data.frame(HR_trigger$contrasts)
ggplot(plot_HRtrigger) + aes(x=contrast, y=estimate, colour=trigger) + geom_pointrange(aes(ymin=estimate-SE, ymax=estimate+SE)  ,position=position_dodge(width=0.5))  + scale_color_manual(values=c('#0072BD', '#D95319'))  + theme(legend.position = 'top')+ ylim(-2, 3)

plot_HRDT<-as.data.frame(HR_DT$emmeans)
ggplot(plot_HRDT) + aes(x=DT, y=emmean, colour=condition) + geom_pointrange(aes(ymin=lower.CL, ymax=upper.CL) ,position=position_dodge(width=0.5))+ scale_color_manual(values=c('#FF0000', '#333FFF', '#33CC33'))+ theme(legend.position = 'top') + ylim(-2.5, 2.5)
plot_HRDT<-as.data.frame(HR_DT$contrasts)
ggplot(plot_HRDT) + aes(x=contrast, y=estimate, colour=DT) + geom_pointrange(aes(ymin=estimate-SE, ymax=estimate+SE)  ,position=position_dodge(width=0.5))  + scale_color_manual(values=c('#0072BD', '#D95319', '#EDB120'))  + theme(legend.position = 'top') +  ylim(-2, 3)


# condition lsmean   SE   df lower.CL upper.CL
# FOG         91.2 2.45 14.3     86.0     96.5
# stop        90.5 2.27 14.0     85.6     95.3
# trigger     91.8 2.38 14.0     86.7     96.9
# 
# Results are averaged over the levels of: trigger, DT, type 
# Degrees-of-freedom method: kenward-roger 
# Confidence level used: 0.95 
# 
# $contrasts
# contrast       estimate    SE   df t.ratio p.value
# FOG - stop        0.754 0.468 27.2  1.611  0.2584 
# FOG - trigger    -0.593 0.483 23.9 -1.228  0.4490 
# stop - trigger   -1.347 0.325 15.7 -4.140  0.0022 
# 
# Results are averaged over the levels of: trigger, DT, type 
# Degrees-of-freedom method: kenward-roger 
# P value adjustment: tukey method for comparing a family of 3 estimates 

lsmeans(mod2, pairwise~condition*type, adjust="tukey")
# condition type      lsmean   SE   df lower.CL upper.CL
# FOG       akinesia    90.4 2.51 15.4     85.0     95.7
# stop      akinesia    90.6 2.27 14.2     85.7     95.4
# trigger   akinesia    91.7 2.38 14.0     86.6     96.8
# FOG       trembling   92.1 2.44 14.1     86.9     97.3
# stop      trembling   90.4 2.27 14.2     85.5     95.2
# trigger   trembling   92.0 2.38 14.0     86.8     97.1
# 
# Results are averaged over the levels of: trigger, DT 
# Degrees-of-freedom method: kenward-roger 
# Confidence level used: 0.95 
#
# $contrasts
# contrast                             estimate    SE     df t.ratio p.value
# FOG akinesia - stop akinesia          -0.2041 0.711   74.1 -0.287  0.9997 
# FOG akinesia - trigger akinesia       -1.3239 0.709   61.2 -1.868  0.4313 
# FOG akinesia - FOG trembling          -1.7285 0.652  187.6 -2.652  0.0901 
# FOG akinesia - stop trembling         -0.0171 0.710   71.8 -0.024  1.0000 
# FOG akinesia - trigger trembling      -1.5914 0.709   61.3 -2.246  0.2323 
# stop akinesia - trigger akinesia      -1.1198 0.366   25.0 -3.061  0.0522 
# stop akinesia - FOG trembling         -1.5244 0.436   23.5 -3.496  0.0207 
# stop akinesia - stop trembling         0.1870 0.297 2475.1  0.630  0.9888 
# stop akinesia - trigger trembling     -1.3874 0.365   25.0 -3.796  0.0096 
# trigger akinesia - FOG trembling      -0.4046 0.434   17.7 -0.932  0.9328 
# trigger akinesia - stop trembling      1.3068 0.365   24.7  3.583  0.0162 
# trigger akinesia - trigger trembling  -0.2676 0.147 2668.9 -1.821  0.4525 
# FOG trembling - stop trembling         1.7114 0.435   23.3  3.931  0.0076 
# FOG trembling - trigger trembling      0.1370 0.434   17.6  0.316  0.9995 
# stop trembling - trigger trembling    -1.5744 0.364   24.7 -4.320  0.0027 
# 
# Results are averaged over the levels of: trigger, DT 
# Degrees-of-freedom method: kenward-roger 
# P value adjustment: tukey method for comparing a family of 6 estimates 

# or
em<-emmeans(mod2, c("condition", "type"))
contrast(em, method="pairwise")

# all conditions together

# fix contrasts
contrast.time<-matrix(c(-1/3, 1/3, -1/3, -1/3, -1/3, 1/3), nrow=3, ncol=2, dimnames=list(c("baseline", "preFOG", "FOG"), c("preFOGvsBL", "FOGvsBL"))) # dummy coding
contrasts(data$time)<-contrast.time
contrasts(data$time)

contrasts(data$trigger)<-contrast.trigger
contrasts(data$trigger)

contrasts(data$DT)<-contrast.DT
contrasts(data$DT)

contrasts(data$condition)<-contrast.cond
contrasts(data$condition)

contrasts(data$type)<-contrast.type
contrasts(data$type)

# build the model
mod3_HR <- lmer(HR ~ condition*time + condition*time*trigger + condition*time*DT + condition*time*type + (1 + condition*time|pid) + (1|trial), data) #random effect (1+time|trial) does not work because number random effects = number of observations (see also instructions holy grail workshop)
mod3_FI <- lmer(FI_R ~ condition*time + condition*time*trigger + condition*time*DT + condition*time*type + (1 + condition*time|pid), data) #random effect (1+time|trial) does not work because number random effects = number of observations (see also instructions holy grail workshop)
summary(mod3_HR)
# Linear mixed model fit by REML ['lmerMod']
# Formula: HR ~ condition * time + condition * time * trigger + condition *      time * DT + condition * time * type + (1 + condition * time |  
#                                                                                                                         pid) + (1 | trial)
# Data: data
# 
# REML criterion at convergence: 33241.8
# 
# Scaled residuals: 
#   Min      1Q  Median      3Q     Max 
# -6.1504 -0.3623  0.0220  0.4070  5.1316 
# 
# Random effects:
#   Groups   Name                            Variance Std.Dev. Corr                                           
# trial    (Intercept)                     10.4485  3.2324                                                  
# pid      (Intercept)                     91.9592  9.5895                                                  
# conditionstop                    2.2292  1.4931   -0.40                                          
# conditiontrigger                 1.9419  1.3935   -0.28  0.89                                    
# timepreFOGvsBL                   0.1450  0.3808    0.69 -0.45 -0.13                              
# timeFOGvsBL                      1.4656  1.2106    0.17  0.25  0.56  0.70                        
# conditionstop:timepreFOGvsBL     0.9572  0.9784   -0.40  0.77  0.68 -0.35  0.22                  
# conditiontrigger:timepreFOGvsBL  0.2573  0.5072   -0.63  0.85  0.69 -0.66 -0.02  0.92            
# conditionstop:timeFOGvsBL        4.7204  2.1726   -0.50 -0.12 -0.31 -0.69 -0.73  0.24  0.38      
# conditiontrigger:timeFOGvsBL     0.8914  0.9441    0.02  0.27 -0.14 -0.66 -0.74  0.19  0.32  0.39
# Residual                                  3.0162  1.7367                                                  
# Number of obs: 6963, groups:  trial, 2321; pid, 15
# 
# Fixed effects:
#   Estimate Std. Error t value
# (Intercept)                                             90.99227    2.50331  36.349*
# conditionstop                                            0.04299    0.59502   0.072
# conditiontrigger                                         0.45149    0.53716   0.841
# timepreFOGvsBL                                           0.39712    0.36339   1.093
# timeFOGvsBL                                              1.09688    0.49335   2.223(*)
# triggerturnvsdoorway                                     1.54161    0.46952   3.283*
# DTcDTvsnDT                                              -1.35746    0.59516  -2.281(*)
# DTmDTvsnDT                                               1.53609    0.64932   2.366(*)
# typetremblingvsakinesia                                 -1.31824    0.66596  -1.979
# conditionstop:timepreFOGvsBL                             0.33810    0.51460   0.657
# conditiontrigger:timepreFOGvsBL                         -0.07233    0.39841  -0.182
# conditionstop:timeFOGvsBL                               -2.17390    0.73604  -2.954
# conditiontrigger:timeFOGvsBL                             0.28616    0.47688   0.600
# conditionstop:triggerturnvsdoorway                      -0.61107    0.59821  -1.021
# conditiontrigger:triggerturnvsdoorway                   -0.81096    0.50372  -1.610
# timepreFOGvsBL:triggerturnvsdoorway                      0.11441    0.47782   0.239
# timeFOGvsBL:triggerturnvsdoorway                        -0.82075    0.49560  -1.656
# conditionstop:DTcDTvsnDT                                -0.67353    0.89122  -0.756
# conditiontrigger:DTcDTvsnDT                             -0.11910    0.67230  -0.177
# conditionstop:DTmDTvsnDT                                 0.05501    1.11764   0.049
# conditiontrigger:DTmDTvsnDT                             -0.54160    0.74104  -0.731
# timepreFOGvsBL:DTcDTvsnDT                               -0.16241    0.62655  -0.259
# timeFOGvsBL:DTcDTvsnDT                                   0.90403    0.63270   1.429
# timepreFOGvsBL:DTmDTvsnDT                                0.16471    0.68366   0.241
# timeFOGvsBL:DTmDTvsnDT                                  -0.89497    0.69018  -1.297
# conditionstop:typetremblingvsakinesia                    1.23605    0.68280   1.810
# conditiontrigger:typetremblingvsakinesia                 1.29734    0.67011   1.936
# timepreFOGvsBL:typetremblingvsakinesia                  -0.13160    0.54483  -0.242
# timeFOGvsBL:typetremblingvsakinesia                     -1.48786    0.66881  -2.225
# conditionstop:timepreFOGvsBL:triggerturnvsdoorway       -0.19771    0.62017  -0.319
# conditiontrigger:timepreFOGvsBL:triggerturnvsdoorway    -0.06090    0.51514  -0.118
# conditionstop:timeFOGvsBL:triggerturnvsdoorway           0.79784    0.63543   1.256
# conditiontrigger:timeFOGvsBL:triggerturnvsdoorway        0.56960    0.53231   1.070
# conditionstop:timepreFOGvsBL:DTcDTvsnDT                  0.91685    0.94403   0.971
# conditiontrigger:timepreFOGvsBL:DTcDTvsnDT               0.15629    0.70787   0.221
# conditionstop:timeFOGvsBL:DTcDTvsnDT                     0.11191    0.95368   0.117
# conditiontrigger:timeFOGvsBL:DTcDTvsnDT                  1.07584    0.71416   1.506
# conditionstop:timepreFOGvsBL:DTmDTvsnDT                 -0.39483    1.18356  -0.334
# conditiontrigger:timepreFOGvsBL:DTmDTvsnDT              -0.19567    0.77914  -0.251
# conditionstop:timeFOGvsBL:DTmDTvsnDT                     0.55380    1.19927   0.462
# conditiontrigger:timeFOGvsBL:DTmDTvsnDT                  0.70542    0.78661   0.897
# conditionstop:timepreFOGvsBL:typetremblingvsakinesia    -0.89141    0.71605  -1.245
# conditiontrigger:timepreFOGvsBL:typetremblingvsakinesia  0.08830    0.59197   0.149
# conditionstop:timeFOGvsBL:typetremblingvsakinesia        0.49271    0.81331   0.606
# conditiontrigger:timeFOGvsBL:typetremblingvsakinesia     1.06111    0.70737   1.500

# check assumptions
plot(fitted(mod3), residuals(mod3))
densityplot(resid(mod3), scaled=TRUE)
densityplot(resid(mod3), group=data$condition, auto.key=TRUE)
densityplot(resid(mod3), group=data$trigger, auto.key=TRUE)
densityplot(resid(mod3), group=data$type, auto.key=TRUE)
densityplot(resid(mod3), group=data$DT, auto.key=TRUE)

sum(abs(resid(mod3, scaled = TRUE)) > 2) / length(resid(mod1)) #  (should be no more than 0.05)
sum(abs(resid(mod3, scaled = TRUE)) > 2.5) / length(resid(mod1)) # 
sum(abs(resid(mod3, scaled = TRUE)) > 3) / length(resid(mod1)) #  (everything here could be an outlier and should be checked)
which(abs(resid(mod3, scaled=TRUE))>3)

plot(mod3_HR, type = c('p', 'smooth')) # fitted vs. residual
qqPlot(resid(mod3_HR, scaled = TRUE))
hist(resid(mod3_HR))

Anova(mod3_HR, test = 'F', type = 3)

lsmeans(mod3, pairwise~condition*time, adjust="tukey")
em<-emmeans(mod3, c("condition", "type"))
contrast(em, method="pairwise")
