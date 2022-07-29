# preparations
library(lme4)
library(lattice)
library(ggplot2)
library(gridExtra)
library(car)
library(dplyr)
library(emmeans)

options(scipen = 20)

# read in data
data<- read.delim('F://Brainwave_exp2/processed/final/dataframe.tsv', sep="\t")
# as factor
data$pid <-as.factor(data$pid)
data$trial <- as.factor(data$trial)
data$time <- factor(data$time, levels=c("baseline", "preFOG", "FOG"))# change order of time
data$trigger <- factor(data$trigger, levels=c("turn", "doorway"))
data$type <- factor(data$type, levels=c("trembling", "akinesia", "shuffling", "stop", "trigger"))
data$DT <- factor(data$DT, levels=c("nDT", "cDT", "mDT"))
data$condition <- factor(data$condition, levels=c("FOG", "trigger", "stop", "congr"))

# exclude PD5
data <- droplevels(subset(data, data$pid !="110005"))
# if exclude PD08
data <- droplevels(subset(data, data$pid !="110008"))

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
mod1_HR <- lmer(HR ~ time*trigger + time*type + time*DT + (1|pid) + (1|trial), data=data_FOG) #random effect (1+time|trial) does not work because number random effects = number of observations (see also instructions holy grail workshop)
summary(mod1_FI)
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

plot(mod1_HR, type = c('p', 'smooth')) # fitted vs. residual
qqPlot(resid(mod1_HR, scaled = TRUE))
hist(resid(mod1_HR))

# anova
A1a<-Anova(mod1_FI, test = 'F', type = 3) #F tests with Roger-Kenward adjustment of degrees of freedom
A1b<-Anova(mod1_HR, test = 'F', type = 3) #F tests with Roger-Kenward adjustment of degrees of freedom
A1a<-as.data.frame(A1a)
A1b<-as.data.frame(A1b)

# post hoc test: https://aosmith.rbind.io/2019/03/25/getting-started-with-emmeans/
#! only correct for multiple comparison within each group
FI_type<-emmeans(mod1_FI, trt.vs.ctrl~time|type) # default = Dunnett adjustment
FI_trigger<-emmeans(mod1_FI, trt.vs.ctrl~time|trigger)
FI_DT<-emmeans(mod1_FI, trt.vs.ctrl~time|DT)

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

plot_all=rbind(plot_FItype, plot_FItrigger, plot_FIDT, plot_HRtype, plot_HRtrigger, plot_HRDT)
plot_all$factor <- factor(plot_all$factor, levels=c("type", "trigger", "DT"))
plot_all$variable <- factor(plot_all$variable, levels=c("FI", "heart rate"))
plot_all$level<-recode(plot_all$level, doorway="narrow passage")
plot_all$level<-recode(plot_all$level, nDT="noDT")
plot_all$signinteraction<-as.factor(c(rep("sign",4), rep("nonsign", 10), rep("sign",4), rep("nonsign", 4 ),rep("sign", 6)))
plot_all$signinteraction<-as.factor(c(rep("nonsign", 8), rep("sign",6), rep("nonsign", 8 ),rep("sign", 6)))
plot_all$newlabel=as.factor(paste(plot_all$contrast, "(", plot_all$signinteraction, ")"))
plot_all$newlabel=factor(plot_all$newlabel, levels=c("preFOG - baseline ( sign )", "FOG - baseline ( sign )", "preFOG - baseline ( nonsign )",  "FOG - baseline ( nonsign )"))


# actual plotting
ggplot(plot_all) + theme_light() + facet_grid(variable ~ factor, scales="free_x", drop=FALSE) +
  aes(x=level, y=estimate, color=newlabel, shape = newlabel)+
  geom_pointrange(aes(ymin=estimate-SE, ymax=estimate+SE), position=position_dodge(width=0.5)) +
  scale_color_manual(name = "", labels = c("preFOG - baseline (sign. interaction)", "FOG - baseline (sign. interaction)", "preFOG - baseline (nonsign. interaction)", "FOG - baseline (nonsign. interaction)"),values=c( '#F0925A', '#D55E00', '#F0925A', '#D55E00'))+
  scale_shape_manual(name = "", labels = c("preFOG - baseline (sign. interaction)", "FOG - baseline (sign. interaction)", "preFOG - baseline (nonsign. interaction)", "FOG - baseline (nonsign. interaction)"), values=c(16,16,1,1))+
  geom_hline(yintercept=0)+ ylab('estimated difference')+
  theme(axis.title.x=element_blank(), plot.title=element_text(hjust = 0.5),legend.position = 'top', text = element_text(size = 15)) +
  guides(color=guide_legend(nrow=2), byrow=TRUE) + 
  ggtitle('Model 1: baseline vs preFOG vs FOG') + 
  ylim(0.0,3.0)



# 2. SECOND MODEL: FOG vs stopping and FOG vs normal gait event

# recalculate HR change as the difference in mean HR of during FOG - preFOG
data_preFOG<-droplevels(subset(data, data$time=='preFOG'))
data_duringFOG<-droplevels(subset(data, data$time=='FOG'))
data_cond <- droplevels(subset(data, data$time=='FOG'))
data_cond$HRCh<- data_duringFOG$HR - data_preFOG$HR
str(data_cond)
summary(data_cond)

# fix contrasts
contrasts(data_cond$type)<-contrast.type
contrasts(data_cond$type)

contrasts(data_cond$trigger)<-contrast.trigger
contrasts(data_cond$trigger)

contrasts(data_cond$DT)<-contrast.DT
contrasts(data_cond$DT)

contrast.cond<-matrix(c(0, -1, 0, 0, 0, -1), nrow=3, ncol=2,dimnames=list(c("FOG","trigger", "stop"), c("triggervsFOG", "stopvsFOG"))) 
contrasts(data_cond$condition)<-contrast.cond
contrasts(data_cond$condition)

# build the model
mod2_HR <- lmer(HRCh ~ condition*trigger + condition*DT + condition*type + (1|pid), data=data_cond) #random effect (1+time|trial) does not work because number random effects = number of observations (see also instructions holy grail workshop)
mod2_FI <- lmer(FI_R ~ condition*trigger + condition*DT + condition*type + (1|pid), data=data_cond) 
summary(mod2_FI)
summary(mod2_mFI)
summary(mod2_HR)

# check assumptions
plot(mod2_FI, type = c('p', 'smooth')) # fitted vs. residual
qqPlot(resid(mod2_FI, scaled = TRUE))
hist(resid(mod2_FI))

plot(mod2_HR, type = c('p', 'smooth')) # fitted vs. residual
qqPlot(resid(mod2_HR, scaled = TRUE))
hist(resid(mod2_HR))

# anova
A2a<-Anova(mod2_FI, test = 'F', type = 3)
# Anova(mod2_mFI, test = 'F', type = 3)
A2b<-Anova(mod2_HR, test = 'F', type = 3)
A2a<-as.data.frame(A2a)
A2b<-as.data.frame(A2b)

# post hoc test
FI_type<-emmeans(mod2_FI, trt.vs.ctrl~condition|type, reverse=TRUE)
FI_trigger<-emmeans(mod2_FI, trt.vs.ctrl~condition|trigger, reverse=TRUE)
FI_DT<-emmeans(mod2_FI, trt.vs.ctrl~condition|DT, reverse=TRUE)
emmeans(mod2_FI, trt.vs.ctrl~type, reverse=TRUE)
emmeans(mod2_FI, trt.vs.ctrl~condition, reverse=TRUE)

HR_type<-emmeans(mod2_HR, trt.vs.ctrl~condition|type, reverse=TRUE)
HR_trigger<-emmeans(mod2_HR, trt.vs.ctrl~condition|trigger,reverse=TRUE)
HR_DT<-emmeans(mod2_HR, trt.vs.ctrl~condition|DT,reverse=TRUE)
emmeans(mod2_HR, trt.vs.ctrl~trigger,reverse=TRUE)
emmeans(mod2_HR, trt.vs.ctrl~DT,reverse=TRUE)
emmeans(mod2_HR, trt.vs.ctrl~type,reverse=TRUE)
emmeans(mod2_HR, trt.vs.ctrl~condition,reverse=TRUE)

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

plot_all=rbind(plot_FItype, plot_FItrigger, plot_FIDT, plot_HRtype, plot_HRtrigger, plot_HRDT)
plot_all$factor <- factor(plot_all$factor, levels=c("type", "trigger", "DT"))
plot_all$variable <- factor(plot_all$variable, levels=c("FI", "heart rate"))
plot_all$level<-recode(plot_all$level, doorway="narrow passage")
plot_all$level<-recode(plot_all$level, nDT="noDT")
plot_all$contrast<-recode(plot_all$contrast, 'FOG - trigger'="FOG - normal gait event")
plot_all$signinteraction<-as.factor(c(rep("sign",18), rep("nonsign", 4), rep("sign",6)))
plot_all$signinteraction<-as.factor(c(rep("nonsign",4), rep("sign", 4), rep("nonsign",10),  rep("sign",10)))
plot_all$newlabel=as.factor(paste(plot_all$contrast, "(", plot_all$signinteraction, ")"))
plot_all$newlabel=factor(plot_all$newlabel, levels=c("FOG - normal gait event ( sign )", "FOG - stop ( sign )", "FOG - normal gait event ( nonsign )",  "FOG - stop ( nonsign )"))

# actual plotting
ggplot(plot_all) + theme_light() + facet_grid(variable ~ factor, scales="free_x", drop=FALSE) +
  aes(x=level, y=estimate, color=newlabel, shape=newlabel) +
  geom_pointrange(aes(ymin=estimate-SE, ymax=estimate+SE), position=position_dodge(width=0.5)) +
  scale_color_manual(name = "", labels = c("FOG - normal gait event (sign. interaction)", "FOG - stop (sign. interaction)", "FOG - normal gait event (nonsign. interaction)", "FOG - stop (nonsign. interaction)"), values=c('#359B73', '#2271B2', '#359B73', '#2271B2'))  +
  scale_shape_manual(name = "", labels = c("FOG - normal gait event (sign. interaction)", "FOG - stop (sign. interaction)", "FOG - normal gait event (nonsign. interaction)", "FOG - stop (nonsign. interaction)"), values = c(16,16, 1,1)) +
  geom_hline(yintercept=0)+
  ylab('estimated difference') +
  theme(axis.title.x=element_blank(), plot.title=element_text(hjust = 0.5),legend.position = 'top', text = element_text(size = 15)) +
  guides(color=guide_legend(nrow=2), byrow=TRUE) + 
  ggtitle('Model 2: FOG vs normal gait event vs stop')
