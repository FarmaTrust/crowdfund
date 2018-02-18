function getEventSignature(abi, name) {
    for (var i = 0; i < abi.length; i++) {
      var item = abi[i];
      if (item.type != "event") continue;
        if (item.name === name)
            var signature = item.name + "(" + item.inputs.map(function (input) { return input.type; }).join(",") + ")";
    }    
    return signature;
}

async function assertRejects(q, msg) {
    let res, catchFlag = false
    try {
        res = await q
    } catch(e) {
        catchFlag = true; 
    } finally {
        if(!catchFlag)
            assert.fail(res, null, msg)
    }
}

function delay(delay) {
    return new Promise(function (resolve) {
      setTimeout(resolve, delay)
    })
  }

module.exports = {
    getEventSignature, 
    assertRejects, 
    delay
}
