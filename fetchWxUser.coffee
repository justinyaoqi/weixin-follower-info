async = require('async')
request = require('request')
_ = require('underscore')
EventEmitter = require('events').EventEmitter

STATUS = {FREE:0, RUNNING:1}


###
拉取公众号下所有关注微信的用户信息
events
'task start', Error, startOpenId
'task finish', Error, info
'user list', Error, userList
'user', Error, userInfo
###
class FetchWxUser extends EventEmitter
  # opt.token
  # opt.tokenUrl      当token失效时，从中控服务器去获取新的token
  # opt.nextOpenid    获取用户列表时的起始openid，当不指定时，从头获取
  # opt.concurrency   同时抓取用户信息的并发数根据机器性能设置1-50
  # opt.debug         输出调试信息
  # opt.retryTimes    http失败重试次数 默认3
  # opt.retryInterval http失败重试间隔 默认1000
  constructor: (@opt)->
    @opt ?= {}
    @opt.token ?= ''
    @opt.tokenUrl ?= ''
    @opt.nextOpenid ?= null
    @opt.concurrency ?= 10
    @opt.concurrency = Math.max(@opt.concurrency, 1)
    @opt.concurrency = Math.min(@opt.concurrency, 50)
    @opt.retryTimes ?= 3
    @opt.retryInterval ?= 1000

    @status = STATUS.FREE
    @fetchedPage = 0
    @fetchedUser = 0

    @mainQueue = {}

    @init()

  reset: ()->
    @status = STATUS.FREE
    @fetchedPage = 0
    @fetchedUser = 0

  init: ()->
    @mainQueue = async.queue (job, done)=>
      @fetchedPage++
      @getUserList job, (err, data)=>
        @emit 'user list', err, data

        if data and data.next_openid
          @mainQueue.push {nextId: data.next_openid}

        if err
          done err, data
        else if data and data.count != 0 and data.data?.openid and _.isArray(data.data.openid)
          openIds = data.data.openid
          @getUsersInfo openIds, (errors, users)->
            done errors, users
        else
          done()

    @mainQueue.drain = ()=>
      @emit 'task finish', null, @stat()
      @reset()

  start: (openid)->
    if @status == STATUS.RUNNING
      @emit 'task start', new Error 'task is running'
      return

    if openid
      @mainQueue.push {nextId: openid}
      @emit 'task start', null, openid
    else
      @mainQueue.push {nextId: @opt.nextOpenid}
      @emit 'task start', null, @opt.nextOpenid

  getUserList: (job, done)->
    url = @genUserListUrl(job.nextId)
    @getJson url, done

  getUsersInfo: (openIds, done)->
    queue = async.queue (job, _done)=>
      @getJson @genUserInfoUrl(job.openid), (error, userInfo)->
        if error
          _done error
        else
          _done error, userInfo
    , @opt.concurrency

    queue.drain = ()->
      done null

    for openid in openIds
      queue.push {openid}, (err, userInfo)=>
        @fetchedUser++
        @emit 'user', err, userInfo

  stat: ()->
    status: @status
    fetchedPage: @fetchedPage
    fetchedUser: @fetchedUser

  getToken: (done)->
    if @opt.tokenUrl
      url = @opt.tokenUrl
    else if @opt.clientId and @opt.clientSecret
      url = "https://api.weixin.qq.com/cgi-bin/token?grant_type=client_credential&appid=#{@opt.clientId}&secret=#{@opt.clientSecret}"
    else
      return done null, access_token:@opt.token
    @getJson url, done

  genUserListUrl: (openid)->
    url = "https://api.weixin.qq.com/cgi-bin/user/get"
    url += "?next_openid=#{openid}" if openid
    return url

  genUserInfoUrl: (openid)->
    "https://api.weixin.qq.com/cgi-bin/user/info?&openid=#{openid}&lang=zh_CN"

  getJson: (url, done)->
    async.retry({times: @opt.retryTimes, interval: @opt.retryInterval}
      , (_done)=>
        opt =
          url: url
          json: true
          qs: access_token: @opt.token
          method: 'get'
        request opt, (error, resp, body)=>
          if error
            _done error
          else if body && body.errcode != undefined
            if body.errcode == 41001
              @getToken (error, data)=>
                if !error
                  @opt.token = data.access_token
                _done new Error 'invalid token'
            else
              _done new Error body.errmsg
          else
            _done error, body
      , done)

module.exports = FetchWxUser
