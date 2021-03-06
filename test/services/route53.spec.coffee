helpers = require('../helpers')
AWS = helpers.AWS

describe 'AWS.Route53', ->

  service = null
  api = null
  beforeEach ->
    service = new AWS.Route53()
    api = service.api.apiVersion

  describe 'setEndpoint', ->
    it 'always enables SSL if no endpoint is set', ->
      service = new AWS.Route53(sslEnabled: false)
      expect(service.endpoint.protocol).to.equal('https:')

    it 'allows overriding SSL if custom endpoint is set', ->
      service = new AWS.Route53(endpoint: 'http://example.com')
      expect(service.endpoint.protocol).to.equal('http:')

  describe 'building requests', ->
    service = new AWS.Route53

    it 'should fix hosted zone ID on input', ->
      req = service.getHostedZone(Id: '/hostedzone/ABCDEFG')
      req.emit('build', [req])
      expect(req.httpRequest.path).to.match(new RegExp('/hostedzone/ABCDEFG$'))

    it 'should fix health check ID on input', ->
      req = service.getHealthCheck(HealthCheckId: '/healthcheck/ABCDEFG')
      req.emit('build', [req])
      expect(req.httpRequest.path).to.match(new RegExp('/healthcheck/ABCDEFG$'))

  describe 'changeResourceRecordSets', ->
    it 'correctly builds the XML document', ->
      xml =
        """
        <ChangeResourceRecordSetsRequest xmlns="https://route53.amazonaws.com/doc/#{api}/">
          <ChangeBatch>
            <Comment>comment</Comment>
            <Changes>
              <Change>
                <Action>CREATE</Action>
                <ResourceRecordSet>
                  <Name>name</Name>
                  <Type>type</Type>
                  <ResourceRecords>
                    <ResourceRecord>
                      <Value>foo.com</Value>
                    </ResourceRecord>
                  </ResourceRecords>
                </ResourceRecordSet>
              </Change>
            </Changes>
          </ChangeBatch>
        </ChangeResourceRecordSetsRequest>
        """
      helpers.mockHttpResponse 200, {}, ''
      # params purposefully ordered differently than api to test ordering of
      # xml elements
      params =
        HostedZoneId: 'zone-id'
        ChangeBatch:
          Changes: [
            {
              ResourceRecordSet:
                Name: 'name'
                Type: 'type'
                ResourceRecords: [
                  { Value: 'foo.com' }
                ]
              Action: 'CREATE',
            }
          ]
          Comment: 'comment'
      service.changeResourceRecordSets params, (err, data) ->
        helpers.matchXML(this.request.httpRequest.body, xml)

  describe 'retryableError', ->
    it 'retryableError returns true for PriorRequestNotComplete errors', ->
      err = {code: 'PriorRequestNotComplete', statusCode: 400}
      expect(service.retryableError(err)).to.be.true

    it 'retryableError returns false for other 400 errors', ->
      err = {code: 'SomeErrorCode', statusCode:400}
      expect(service.retryableError(err)).to.be.false
