{
  local this = self,

  Bucket:: error 'Bucket name must be provided',
  Actions:: error 'Actions list must be provided (possible values are list, read, write, delete)',

  Version: '2012-10-17',
  Statement: std.prune([
    if std.member(this.Actions, '*') then {
      Effect: 'Allow',
      Action: [
        's3:*',
      ],
      Resource: [
        'arn:aws:s3:::%s' % [this.Bucket],
        'arn:aws:s3:::%s/*' % [this.Bucket],
      ],
    } else null,

    if std.member(this.Actions, 'list') then {
      Effect: 'Allow',
      Action: [
        's3:ListBucket',
      ],
      Resource: [
        'arn:aws:s3:::%s' % [this.Bucket],
      ],
    } else null,

    if std.member(this.Actions, 'write') then {
      Effect: 'Allow',
      Action: [
        's3:PutObject',
      ],
      Resource: [
        'arn:aws:s3:::%s/*' % [this.Bucket],
      ],
    } else null,

    if std.member(this.Actions, 'read') then {
      Effect: 'Allow',
      Action: [
        's3:GetObject',
      ],
      Resource: [
        'arn:aws:s3:::%s/*' % [this.Bucket],
      ],
    } else null,

    if std.member(this.Actions, 'delete') then {
      Effect: 'Allow',
      Action: [
        's3:DeleteObject',
      ],
      Resource: [
        'arn:aws:s3:::%s/*' % [this.Bucket],
      ],
    } else null,
  ]),
}
