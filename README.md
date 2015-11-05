# 自动获取微信公众号所有关注用户信息

# Options
```
opt.token
opt.tokenUrl      当token失效时，从中控服务器去获取新的token
opt.nextOpenid    获取用户列表时的起始openid，当不指定时，从头获取
opt.concurrency   同时抓取用户信息的并发数根据机器性能设置1-50
opt.debug         输出调试信息
opt.retryTimes    http失败重试次数 默认3
opt.retryInterval http失败重试间隔 默认1000
```

# Events
```
'task start', Error, startOpenId  任务开始
'task finish', Error, info        任务完成
'user list', Error, userList      返回用户列表
'user', Error, userInfo           返回单个用户信息
```

# Simple Usage
```
fetcher = new FetchWxUser(token: 'your token')

fetcher.on 'task start', (error)->
  console.log 'task start', error

fetcher.on 'task finish', (error, info)->
  console.log 'task finish', error, info

fetcher.on 'user list', (err, userList)->
  console.log 'user list', err, userList

fetcher.on 'user', (err, user)->
  console.log 'user', err, user

fetcher.start()
```
